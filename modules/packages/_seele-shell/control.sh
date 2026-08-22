#!/usr/bin/env bash
set -euo pipefail

seele_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/seele-shell
tray_config=$seele_config_dir/tray.json
librepods_config=${XDG_CONFIG_HOME:-$HOME/.config}/AirPodsTrayApp/AirPodsTrayApp.conf
bluetooth_scan_pidfile=${XDG_RUNTIME_DIR:-/tmp}/seele-shell/bluetooth-scan.pid
bluetooth_scan_timeout=180

percent_for() {
  awk '{ printf "%d", $2 * 100 }' <<<"$1"
}

audio_devices() {
  jq -c '
    [.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default") | .metadata[]?] as $meta
    | (($meta | map(select(.key == "default.audio.sink")) | first).value.name // "") as $sink
    | (($meta | map(select(.key == "default.audio.source")) | first).value.name // "") as $source
    | [ .[]
        | select(.info.props["media.class"] == "Audio/Sink" or .info.props["media.class"] == "Audio/Source")
        | {
            id: .id,
            kind: (if .info.props["media.class"] == "Audio/Sink" then "output" else "input" end),
            name: (.info.props["node.description"] // .info.props["node.nick"] // .info.props["node.name"] // ""),
            node: (.info.props["node.name"] // "")
          }
      ]
    | map(. + { default: (if .kind == "output" then .node == $sink else .node == $source end) })
    | sort_by([.kind, (.name | ascii_downcase)])
  ' <<<"$1"
}

agent_processes() {
  # Reading /proc through awk keeps this in the tens of milliseconds; a shell
  # loop over every pid made each control action feel sluggish.
  {
    awk 'FNR == 1 {
      name = $0
      sub(/^\./, "", name)
      sub(/-wrapp(ed)?$/, "", name)
      if (name == "pi" || name == "opencode" || name == "codex" || name == "claude") print name
    }' /proc/[0-9]*/comm 2>/dev/null
    awk 'BEGIN { RS = "\0" }
      FNR == 1 {
        name = $0
        sub(/.*\//, "", name)
        sub(/^\./, "", name)
        sub(/-wrapp(ed)?$/, "", name)
        if (name ~ /^(pi|opencode|codex|claude)$/) print name
        nextfile
      }' /proc/[0-9]*/cmdline 2>/dev/null
  } | jq -Rsc 'split("\n") | map(select(length > 0)) | unique'
}

screen_recording() {
  if jq -e 'any(.[]; (.info.props["media.class"] // "") == "Stream/Output/Video" and (.info.state // "") == "running")' <<<"$1" >/dev/null 2>&1; then
    printf 'true'
    return
  fi
  if awk 'FNR == 1 {
      name = $0
      sub(/^\./, "", name)
      if (name ~ /^(wf-recorder|wl-screenrec|obs|gpu-screen|kooha|simplescreenr)/) { found = 1; exit }
    }
    END { exit !found }' /proc/[0-9]*/comm 2>/dev/null; then
    printf 'true'
  else
    printf 'false'
  fi
}

live_agent_records() {
  local records=$1 pid
  while IFS= read -r pid; do
    if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
    fi
  done < <(jq -r '.[].pid // empty' <<<"$records") |
    jq -Rsc 'split("\n") | map(select(length > 0) | tonumber) | unique' |
    jq -c --argjson records "$records" '. as $pids | $records | map(select(.pid as $pid | $pids | index($pid)))'
}

agent_states() {
  local state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/seele-shell/agents
  local files=() records running live
  if [[ -d $state_dir ]]; then
    shopt -s nullglob
    files=("$state_dir"/*.json)
    shopt -u nullglob
  fi
  if ((${#files[@]} > 0)); then
    records=$(jq -s 'map(select(type == "object" and (.agent | type) == "string"))' "${files[@]}" 2>/dev/null || printf '[]')
  else
    records='[]'
  fi
  running=$(agent_processes)
  live=$(live_agent_records "$records")
  jq -nc --argjson records "$records" --argjson running "$running" --argjson live "$live" '
    def timestamp: .updatedAt // .endedAt // .startedAt // "";
    def status($items):
      if any($items[]; .status == "input") then "input"
      elif any($items[]; .status == "working") then "working"
      elif any($items[]; .status == "running") then "running"
      else ($items | sort_by(timestamp) | last | .status // "running")
      end;
    reduce (([$running[], $records[].agent] | unique)[]) as $agent ({};
      ($records | map(select(.agent == $agent)) | sort_by(timestamp)) as $saved
      | ($live | map(select(.agent == $agent and .source == "native"))) as $native
      | ($live | map(select(.agent == $agent and .source != "native"))) as $heuristic
      | ((($running | index($agent)) != null) or (($native + $heuristic) | length > 0)) as $active
      | ($saved | last // {agent:$agent}) as $latest
      | (($native | sort_by(timestamp) | last) // ($heuristic | sort_by(timestamp) | last) // $latest) as $base
      | . + { ($agent): (
          $base + {
            agent: $agent,
            active: $active,
            status: (
              if ($native | length) > 0 then status($native)
              elif ($heuristic | length) > 0 then status($heuristic)
              elif $active then "running"
              elif ($latest.status == "working" or $latest.status == "input" or $latest.status == "running") then "idle"
              else ($latest.status // "idle")
              end
            )
          }
        ) }
    )
  '
}

notification_state() {
  local active history times now state_file result
  state_file=${XDG_STATE_HOME:-$HOME/.local/state}/seele-shell/notification-times.json
  active=$(makoctl list -j 2>/dev/null || printf '[]')
  history=$(makoctl history -j 2>/dev/null || printf '[]')
  now=$(date +%s)
  times='{}'
  if [[ -r $state_file ]]; then
    times=$(jq -c 'if type == "object" then . else {} end' "$state_file" 2>/dev/null || printf '{}')
  fi
  # mako does not timestamp notifications, so remember when each id first
  # appeared and use that to build the 24 hour history view.
  result=$(jq -nc \
    --argjson active "$active" \
    --argjson history "$history" \
    --argjson times "$times" \
    --argjson now "$now" '
    def stamp($entries; $seen): reduce $entries[] as $entry ($seen;
      if has(($entry.id | tostring)) then . else . + { ($entry.id | tostring): $now } end);
    ($times | with_entries(select(.value > ($now - 86400)))) as $kept
    | stamp($active + $history; $kept) as $stamps
    | def at($entry): $stamps[($entry.id | tostring)] // $now;
      {
        stamps: $stamps,
        count: ($active | length),
        items: ($active | map(. + { time: at(.) }) | reverse),
        history: (
          $history
          | map(select(($stamps[(.id | tostring)] // 0) > ($now - 86400)))
          | map(. + { time: at(.) })
          | reverse
          | .[:40]
        )
      }')
  mkdir -p "${state_file%/*}"
  jq -c '.stamps' <<<"$result" >"$state_file.new" && mv "$state_file.new" "$state_file"
  jq -c 'del(.stamps)' <<<"$result"
}

bluetooth_scan_active() {
  local pid
  [[ -r $bluetooth_scan_pidfile ]] || return 1
  pid=$(<"$bluetooth_scan_pidfile")
  [[ -n $pid && -r /proc/$pid/comm && $(</proc/"$pid"/comm) == bluetoothctl ]]
}

bluetooth_state() {
  local objects scanning=false
  if bluetooth_scan_active; then scanning=true; fi
  objects=$(busctl --json=short call org.bluez / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null) || objects=""
  if [[ -z $objects ]]; then
    printf '{"available":false,"powered":false,"scanning":false,"connected":0,"devices":[],"airpodsConnected":false,"airpodsName":""}'
    return
  fi
  jq -c --argjson scanning "$scanning" '
    (.data[0] // {}) as $objects
    | [$objects[]["org.bluez.Adapter1"] // empty] as $adapters
    | ([$objects[]
        | select(.["org.bluez.Device1"])
        | . as $interfaces
        | .["org.bluez.Device1"] as $device
        | {
            address: ($device.Address.data // ""),
            name: ($device.Alias.data // $device.Name.data // $device.Address.data // ""),
            icon: ($device.Icon.data // ""),
            paired: ($device.Paired.data // false),
            trusted: ($device.Trusted.data // false),
            connected: ($device.Connected.data // false),
            rssi: ($device.RSSI.data // null),
            battery: ($interfaces["org.bluez.Battery1"].Percentage.data // null)
          }
        | select(.address != "" and .name != "")
        | select(.paired or .connected or (.name | ascii_downcase) != (.address | ascii_downcase | gsub(":"; "-")))
      ] | sort_by([(if .connected then 0 else 1 end), (if .paired then 0 else 1 end), (.name | ascii_downcase)])) as $devices
    | ([$devices[] | select(.connected and (.name | test("airpods|beats"; "i")))] | first) as $airpods
    | {
        available: ($adapters | length > 0),
        powered: ([$adapters[] | select(.Powered.data == true)] | length > 0),
        scanning: $scanning,
        connected: ([$devices[] | select(.connected)] | length),
        devices: $devices,
        airpodsConnected: ($airpods != null),
        airpodsName: ($airpods.name // "")
      }
  ' <<<"$objects"
}

bluetooth_scan_stop() {
  local pid=""
  if [[ -r $bluetooth_scan_pidfile ]]; then
    pid=$(<"$bluetooth_scan_pidfile")
    rm -f "$bluetooth_scan_pidfile"
  fi
  if [[ -n $pid && -r /proc/$pid/comm && $(</proc/"$pid"/comm) == bluetoothctl ]]; then
    kill "$pid" 2>/dev/null || true
  fi
  timeout 5 bluetoothctl scan off >/dev/null 2>&1 || true
}

bluetooth_scan_start() {
  bluetooth_scan_stop
  bluetoothctl power on >/dev/null 2>&1 || true
  mkdir -p "${bluetooth_scan_pidfile%/*}"
  setsid bash -c 'echo $$ >"$1"; shift; exec "$@"' seele-bluetooth-scan "$bluetooth_scan_pidfile" \
    bluetoothctl --timeout "$bluetooth_scan_timeout" scan on >/dev/null 2>&1 &
  for _ in $(seq 1 20); do
    if bluetooth_scan_active; then break; fi
    sleep 0.05
  done
}

bluetooth_paired() {
  jq -r --arg address "$1" 'any(.devices[]; .address == $address and .paired)' <<<"$(bluetooth_state)"
}

bluetooth_pair_terminal() {
  local address=$1 script=${XDG_RUNTIME_DIR:-/tmp}/seele-shell/pair.bt
  bluetooth_scan_stop
  mkdir -p "${script%/*}"
  printf 'agent KeyboardDisplay\ndefault-agent\npair %s\n' "$address" >"$script"
  setsid -f ghostty --title="Bluetooth pairing" -e bash -c '
    printf "Pairing %s\n\nAnswer any passkey or confirmation prompt, then type: quit\n\n" "$2"
    bluetoothctl --init-script "$1" || true
    bluetoothctl trust "$2" >/dev/null 2>&1 || true
    bluetoothctl connect "$2" || true
    printf "\nPress enter to close this window.\n"
    read -r _
  ' seele-bluetooth-pair "$script" "$address" >/dev/null 2>&1
}

tray_hidden() {
  if [[ -r $tray_config ]]; then
    jq -c '[(.hidden // [])[] | select(type == "string")]' "$tray_config" 2>/dev/null || printf '[]'
  else
    printf '[]'
  fi
}

tray_set_hidden() {
  local id=$1 action=$2 hidden
  hidden=$(tray_hidden)
  mkdir -p "$seele_config_dir"
  jq -nc --argjson hidden "$hidden" --arg id "$id" --arg action "$action" '
    (($hidden | index($id)) != null) as $present
    | (if $action == "hide" or ($action == "toggle" and ($present | not))
       then ($hidden + [$id] | unique)
       else ($hidden - [$id])
       end)
    | { hidden: . }' >"$tray_config.new"
  mv "$tray_config.new" "$tray_config"
}

upower_batteries() {
  local paths path properties entries=()
  paths=$(busctl --json=short call org.freedesktop.UPower /org/freedesktop/UPower \
    org.freedesktop.UPower EnumerateDevices 2>/dev/null | jq -r '.data[0][]? // empty' 2>/dev/null || true)
  while IFS= read -r path; do
    [[ -n $path ]] || continue
    [[ $path == */DisplayDevice ]] && continue
    properties=$(busctl --json=short call org.freedesktop.UPower "$path" \
      org.freedesktop.DBus.Properties GetAll s org.freedesktop.UPower.Device 2>/dev/null) || continue
    entries+=("$(jq -c '
      (.data[0] // {}) as $device
      | {
          kind: (if ($device.PowerSupply.data // false) then "system" else "device" end),
          name: (($device.Model.data // "") | if . == "" then "Battery" else . end),
          percent: (($device.Percentage.data // 0) | round),
          status: (
            {"1": "Charging", "2": "Discharging", "3": "Empty", "4": "Full", "5": "Charging", "6": "Discharging"}[
              ($device.State.data // 0) | tostring
            ] // "Unknown"
          ),
          icon: "",
          present: (($device.IsPresent.data // false) and (($device.Type.data // 0) != 1))
        }
      | select(.present and .percent > 0)
      | del(.present)
    ' <<<"$properties" 2>/dev/null || true)")
  done <<<"$paths"
  if ((${#entries[@]} > 0)); then
    printf '%s\n' "${entries[@]}" | jq -sc 'map(select(type == "object"))'
  else
    printf '[]'
  fi
}

airpods_batteries() {
  local state
  state=$(timeout 2 librepods-ctl status 2>/dev/null) || state='{"batteries":[]}'
  jq -c '[
    .batteries[]?
    | select((.percent // 0) > 0)
    | {
        kind: "device",
        name: .name,
        percent: (.percent | round),
        status: (.status // ""),
        icon: "audio-headphones"
      }
  ]' <<<"$state" 2>/dev/null || printf '[]'
}

system_batteries() {
  local supply type capacity status name entries=()
  shopt -s nullglob
  for supply in /sys/class/power_supply/*; do
    type=$(cat "$supply/type" 2>/dev/null || true)
    [[ $type == Battery ]] || continue
    capacity=$(cat "$supply/capacity" 2>/dev/null || true)
    [[ $capacity =~ ^[0-9]+$ ]] || continue
    status=$(cat "$supply/status" 2>/dev/null || printf 'Unknown')
    name=$(cat "$supply/model_name" 2>/dev/null || true)
    [[ -n $name ]] || name=${supply##*/}
    entries+=("$(jq -nc --arg name "$name" --argjson percent "$capacity" --arg status "$status" \
      '{kind:"system",name:$name,percent:$percent,status:$status,icon:""}')")
  done
  shopt -u nullglob
  if ((${#entries[@]} > 0)); then
    printf '%s\n' "${entries[@]}" | jq -sc '.'
  else
    printf '[]'
  fi
}

airpods_ear_detection() {
  local value
  value=$(awk -F= '/^\[/ { section = $0 } section == "[earDetection]" && $1 == "setting" { print $2 }' \
    "$librepods_config" 2>/dev/null | tail -1)
  [[ ${value:-0} == 2 ]] && printf 'false' || printf 'true'
}

airpods_set_ear_detection() {
  local target=$1 value=2 current temp
  current=$(airpods_ear_detection)
  case "$target" in
    on) value=0 ;;
    off) value=2 ;;
    toggle) [[ $current == true ]] && value=2 || value=0 ;;
    *) return 2 ;;
  esac
  systemctl --user stop librepods.service >/dev/null 2>&1 || true
  mkdir -p "${librepods_config%/*}"
  temp=$(mktemp "${librepods_config}.XXXXXX")
  if [[ -f $librepods_config ]]; then
    awk '/^\[/ { skip = ($0 == "[earDetection]") } !skip { print }' "$librepods_config" >"$temp"
  fi
  printf '[earDetection]\nsetting=%s\n' "$value" >>"$temp"
  mv "$temp" "$librepods_config"
  systemctl --user start librepods.service >/dev/null 2>&1 || true
}

status() {
  audio=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || printf 'Volume: 0.00')
  volume=$(percent_for "$audio")
  muted=false
  [[ $audio == *MUTED* ]] && muted=true

  microphone=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || printf 'Volume: 0.00')
  microphone_volume=$(percent_for "$microphone")
  microphone_muted=false
  [[ $microphone == *MUTED* ]] && microphone_muted=true

  connection_line=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1 ~ /(wireless|ethernet|wifi)/ {print; exit}')
  connection_type=${connection_line%%:*}
  connection=${connection_line#*:}
  [[ -n $connection_line ]] || {
    connection_type=""
    connection="Disconnected"
  }
  wifi_available=false
  nmcli -t -f TYPE device 2>/dev/null | grep -qx wifi && wifi_available=true
  wifi_enabled=false
  [[ $(nmcli -t -f WIFI general 2>/dev/null || true) == enabled ]] && wifi_enabled=true
  connectivity=$(nmcli networking connectivity 2>/dev/null || printf 'unknown')

  route=$(ip -json route get 1.1.1.1 2>/dev/null || printf '[]')
  ip_address=$(jq -r '.[0].prefsrc // ""' <<<"$route")
  gateway=$(jq -r '.[0].gateway // ""' <<<"$route")

  bluetooth=$(bluetooth_state)
  batteries=$(jq -sc "add | unique_by(.name)" <(upower_batteries) <(system_batteries) <(airpods_batteries))
  ear_detection=$(airpods_ear_detection)
  tray_hidden=$(tray_hidden)

  voxtype_status=$(voxtype status 2>/dev/null | head -1 || printf 'unavailable')
  [[ -n $voxtype_status ]] || voxtype_status=unavailable

  camera_devices=$(v4l2-ctl --list-devices 2>/dev/null |
    awk '/^[^[:space:]]/ {name=$0; sub(/:$/, "", name)} /^[[:space:]]*\/dev\/video/ {print name "\t" $1}' |
    jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {name:.[0],device:.[1]})')
  camera_device=$(jq -r '.[0].device // ""' <<<"$camera_devices")
  pw_dump=$(pw-dump 2>/dev/null || printf '[]')
  audio_devices=$(audio_devices "$pw_dump")
  microphone_active=false
  if jq -e 'any(.[]; .info.props["media.class"] == "Stream/Input/Audio" and .info.state == "running")' <<<"$pw_dump" >/dev/null 2>&1; then
    microphone_active=true
  fi
  screen_recording=$(screen_recording "$pw_dump")
  camera_active=false
  if jq -e 'any(.[].info?; .state == "running" and .props["media.class"] == "Video/Source")' <<<"$pw_dump" >/dev/null 2>&1; then
    camera_active=true
  fi

  dnd=false
  makoctl mode 2>/dev/null | grep -qx 'do-not-disturb' && dnd=true
  agents=$(agent_states)
  notifications=$(notification_state)

  jq -nc \
    --argjson volume "$volume" \
    --argjson muted "$muted" \
    --argjson microphoneVolume "$microphone_volume" \
    --argjson microphoneMuted "$microphone_muted" \
    --argjson microphoneActive "$microphone_active" \
    --arg connection "$connection" \
    --arg connectionType "$connection_type" \
    --arg connectivity "$connectivity" \
    --argjson wifiEnabled "$wifi_enabled" \
    --argjson wifiAvailable "$wifi_available" \
    --arg ipAddress "$ip_address" \
    --arg gateway "$gateway" \
    --argjson bluetooth "$bluetooth" \
    --argjson batteries "$batteries" \
    --argjson earDetection "$ear_detection" \
    --argjson trayHidden "$tray_hidden" \
    --arg voxtypeStatus "$voxtype_status" \
    --argjson cameraDevices "$camera_devices" \
    --arg cameraDevice "$camera_device" \
    --argjson cameraActive "$camera_active" \
    --argjson screenRecording "$screen_recording" \
    --argjson audioDevices "$audio_devices" \
    --argjson agentStates "$agents" \
    --argjson notifications "$notifications" \
    --argjson dnd "$dnd" \
    '{
      volume:$volume,
      muted:$muted,
      microphoneVolume:$microphoneVolume,
      microphoneMuted:$microphoneMuted,
      microphoneActive:$microphoneActive,
      connection:$connection,
      connectionType:$connectionType,
      connectivity:$connectivity,
      wifiEnabled:$wifiEnabled,
      wifiAvailable:$wifiAvailable,
      ipAddress:$ipAddress,
      gateway:$gateway,
      bluetoothAvailable:$bluetooth.available,
      bluetoothPowered:$bluetooth.powered,
      bluetoothScanning:$bluetooth.scanning,
      bluetoothConnected:$bluetooth.connected,
      bluetoothDevices:$bluetooth.devices,
      airpodsConnected:$bluetooth.airpodsConnected,
      airpodsName:$bluetooth.airpodsName,
      airpodsEarDetection:$earDetection,
      trayHidden:$trayHidden,
      batteries:(
        $batteries
        + [$bluetooth.devices[] | select(.connected and .battery != null) | {kind:"device",name:.name,percent:.battery,status:"",icon:.icon}]
        | unique_by(.name)
      ),
      voxtypeStatus:$voxtypeStatus,
      cameraDevices:$cameraDevices,
      cameraDevice:$cameraDevice,
      cameraActive:$cameraActive,
      screenRecording:$screenRecording,
      audioDevices:$audioDevices,
      agentStates:$agentStates,
      notifications:$notifications,
      dnd:$dnd
    }'
}

case "${1:-status}" in
  status) status ;;
  volume)
    case "${2:-}" in
      up) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
      down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
      mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
      ''|*[!0-9]*) exit 2 ;;
      *) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${2}%" ;;
    esac
    status
    ;;
  audio-device)
    device=${2:?device id required}
    [[ $device =~ ^[0-9]+$ ]] || exit 2
    wpctl set-default "$device"
    status
    ;;
  microphone)
    case "${2:-}" in
      mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
      up) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ 5%+ ;;
      down) wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- ;;
      ''|*[!0-9]*) exit 2 ;;
      *) wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ "${2}%" ;;
    esac
    status
    ;;
  voxtype)
    voxtype record toggle >/dev/null
    status
    ;;
  wifi)
    target=${2:-toggle}
    if [[ $target == toggle ]]; then
      [[ $(nmcli -t -f WIFI general 2>/dev/null || true) == enabled ]] && target=off || target=on
    fi
    nmcli radio wifi "$target"
    status
    ;;
  bluetooth)
    case "${2:-toggle}" in
      toggle)
        if [[ $(jq -r '.powered' <<<"$(bluetooth_state)") == true ]]; then
          bluetooth_scan_stop
          bluetoothctl power off >/dev/null
        else
          bluetoothctl power on >/dev/null
        fi
        ;;
      scan)
        case "${3:-toggle}" in
          on) bluetooth_scan_start ;;
          off) bluetooth_scan_stop ;;
          toggle)
            if [[ $(jq -r '.scanning' <<<"$(bluetooth_state)") == true ]]; then
              bluetooth_scan_stop
            else
              bluetooth_scan_start
            fi
            ;;
          *) exit 2 ;;
        esac
        ;;
      connect)
        address=${3:?device address required}
        bluetoothctl power on >/dev/null 2>&1 || true
        if [[ $(bluetooth_paired "$address") == true ]]; then
          bluetooth_scan_stop
          timeout 20 bluetoothctl connect "$address" >/dev/null 2>&1 || true
        else
          bluetooth_pair_terminal "$address"
        fi
        ;;
      pair)
        address=${3:?device address required}
        bluetoothctl power on >/dev/null 2>&1 || true
        bluetooth_pair_terminal "$address"
        ;;
      forget)
        address=${3:?device address required}
        timeout 20 bluetoothctl remove "$address" >/dev/null 2>&1 || true
        ;;
      trust)
        address=${3:?device address required}
        case "${4:-toggle}" in
          on) timeout 10 bluetoothctl trust "$address" >/dev/null 2>&1 || true ;;
          off) timeout 10 bluetoothctl untrust "$address" >/dev/null 2>&1 || true ;;
          toggle)
            if [[ $(jq -r --arg address "$address" 'any(.devices[]; .address == $address and .trusted)' <<<"$(bluetooth_state)") == true ]]; then
              timeout 10 bluetoothctl untrust "$address" >/dev/null 2>&1 || true
            else
              timeout 10 bluetoothctl trust "$address" >/dev/null 2>&1 || true
            fi
            ;;
          *) exit 2 ;;
        esac
        ;;
      disconnect)
        address=${3:?device address required}
        timeout 20 bluetoothctl disconnect "$address" >/dev/null 2>&1 || true
        ;;
      *) exit 2 ;;
    esac
    status
    ;;
  airpods)
    case "${2:-}" in
      off|anc|transparency|adaptive) librepods-ctl "noise:${2}" ;;
      ear-detection) airpods_set_ear_detection "${3:-toggle}" ;;
      open)
        # Reuse the running instance so the tray icon is not duplicated.
        if ! timeout 5 librepods-ctl reopen >/dev/null 2>&1; then
          setsid -f librepods >/dev/null 2>&1
        fi
        ;;
      *) exit 2 ;;
    esac
    status
    ;;
  tray)
    case "${2:-}" in
      hide|show|toggle) tray_set_hidden "${3:?tray item id required}" "${2}" ;;
      *) exit 2 ;;
    esac
    status
    ;;
  camera-settings)
    setsid -f cameractrlsgtk4 >/dev/null 2>&1
    status
    ;;
  camera-preview)
    device=${2:-$(v4l2-ctl --list-devices 2>/dev/null | awk '/^[[:space:]]*\/dev\/video/ {print $1; exit}')}
    [[ -n $device ]]
    setsid -f cameraview -d "$device" >/dev/null 2>&1
    status
    ;;
  notifications)
    case "${2:-}" in
      restore) makoctl restore >/dev/null 2>&1 || true ;;
      dismiss)
        notification_id=${3:?notification id required}
        [[ $notification_id =~ ^[0-9]+$ ]] || exit 2
        makoctl dismiss -n "$notification_id" >/dev/null 2>&1 || true
        ;;
      clear)
        makoctl dismiss --all --no-history >/dev/null 2>&1 || true
        for _ in $(seq 1 50); do
          [[ $(makoctl history -j 2>/dev/null | jq 'length') == 0 ]] && break
          makoctl restore >/dev/null 2>&1 || break
          makoctl dismiss --no-history >/dev/null 2>&1 || break
        done
        ;;
      *) exit 2 ;;
    esac
    status
    ;;
  copy-ip)
    ip -json route get 1.1.1.1 2>/dev/null | jq -r '.[0].prefsrc // empty' | wl-copy
    status
    ;;
  network-settings)
    setsid -f nm-connection-editor >/dev/null 2>&1
    status
    ;;
  dnd)
    makoctl mode -t do-not-disturb >/dev/null
    status
    ;;
  tray-menu)
    wanted_id=${2:?tray item id required}
    read -r cursor_x cursor_y < <(hyprctl cursorpos -j | jq -r '[.x, .y] | @tsv')
    while IFS= read -r address; do
      service=${address%%/*}
      object=/${address#*/}
      item_id=$(busctl --user --json=short get-property "$service" "$object" org.kde.StatusNotifierItem Id 2>/dev/null | jq -r '.data // empty')
      if [[ $item_id == "$wanted_id" ]]; then
        busctl --user call "$service" "$object" org.kde.StatusNotifierItem ContextMenu ii "$cursor_x" "$cursor_y" >/dev/null
        exit 0
      fi
    done < <(busctl --user --json=short get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems | jq -r '.data[]')
    exit 1
    ;;
  lock) hyprlock ;;
  lock-suspend)
    hyprlock --immediate &
    sleep 1
    systemctl suspend
    ;;
  logout) hyprctl dispatch exit ;;
  reboot) systemctl reboot ;;
  shutdown) systemctl poweroff ;;
  reboot-windows) systemctl --no-block start reboot-windows.service ;;
  *) exit 2 ;;
esac
