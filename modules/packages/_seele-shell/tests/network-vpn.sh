#!/usr/bin/env bash
set -euo pipefail

control=${1:?control script required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
export XDG_CONFIG_HOME=$work/config
export XDG_STATE_HOME=$work/state
sed '/^case "${1:-status}" in/,$d' "$control" >"$work/functions.sh"

cat >"$work/bin/tailscale" <<'SH'
#!/usr/bin/env bash
if [[ ${1:-} == status && ${2:-} == --json ]]; then
  printf '%s\n' "$MOCK_TAILSCALE_JSON"
else
  printf 'tailscale %s\n' "$*" >>"$MOCK_ACTIONS"
fi
SH
cat >"$work/bin/protonvpn" <<'SH'
#!/usr/bin/env bash
printf 'protonvpn %s\n' "$*" >>"$MOCK_ACTIONS"
SH
cat >"$work/bin/protonvpn-app" <<'SH'
#!/usr/bin/env bash
printf 'protonvpn-app %s\n' "$*" >>"$MOCK_ACTIONS"
SH
cat >"$work/bin/nmcli" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_NMCLI:-}"
exit "${MOCK_NMCLI_EXIT:-0}"
SH
cat >"$work/bin/speedtest" <<'SH'
#!/usr/bin/env bash
printf 'speedtest %s\n' "$*" >>"$MOCK_ACTIONS"
printf '%s\n' \
  '{"type":"ping","ping":{"latency":12.34,"jitter":1.23}}' \
  '{"type":"download","download":{"bandwidth":57097500}}' \
  '{"type":"upload","upload":{"bandwidth":2931250}}' \
  '{"type":"result","ping":{"latency":12.34,"jitter":1.23},"download":{"bandwidth":57097500},"upload":{"bandwidth":2931250},"server":{"name":"Fixture Server"}}'
SH
cat >"$work/bin/vicinae" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  state) [[ $(cat "$MOCK_VICINAE_STATE") == open ]] ;;
  open) printf '%s\n' open >"$MOCK_VICINAE_STATE" ;;
  close) printf '%s\n' closed >"$MOCK_VICINAE_STATE" ;;
  *) exit 2 ;;
esac
SH
cat >"$work/bin/v4l2-ctl" <<'SH'
#!/usr/bin/env bash
cat <<'OUT'
Fixture Camera (usb-0000:00:14.0-7):
        /dev/video0
OUT
SH
for mock in "$work/bin/"*; do
  sed -i "1c#!$BASH" "$mock"
done
chmod +x "$work/bin/"*

export PATH="$work/bin:$PATH"
export MOCK_ACTIONS="$work/actions"
export MOCK_VICINAE_STATE="$work/vicinae-state"
export MOCK_TAILSCALE_JSON='{"BackendState":"Running","Self":{"HostName":"fixture-host","TailscaleIPs":["100.64.0.1"]},"CurrentTailnet":{"Name":"fixture.ts.net"},"Peer":{"one":{"Online":true},"two":{"Online":false}}}'
export MOCK_NMCLI='wireguard:Proton VPN DE#1'

printf '%s\n' open >"$MOCK_VICINAE_STATE"
bash -c 'source "$1"; launcher_toggle' _ "$work/functions.sh"
grep -qx closed "$MOCK_VICINAE_STATE"
bash -c 'source "$1"; launcher_toggle' _ "$work/functions.sh"
grep -qx open "$MOCK_VICINAE_STATE"

state=$(bash -c 'source "$1"; tailscale_state' _ "$work/functions.sh")
jq -e '
  .available and .connected and (.needsLogin | not)
  and .name == "fixture-host" and .ip == "100.64.0.1"
  and .tailnet == "fixture.ts.net" and .peers == 2 and .onlinePeers == 1
' <<<"$state" >/dev/null

state=$(bash -c 'source "$1"; proton_vpn_state' _ "$work/functions.sh")
jq -e '.available and .connected and .connection == "Proton VPN DE#1"' <<<"$state" >/dev/null

export MOCK_TAILSCALE_JSON='{"BackendState":"NeedsLogin"}'
state=$(bash -c 'source "$1"; tailscale_state' _ "$work/functions.sh")
jq -e '.available and (.connected | not) and .needsLogin' <<<"$state" >/dev/null

export MOCK_NMCLI=''
state=$(bash -c 'source "$1"; proton_vpn_state' _ "$work/functions.sh")
jq -e '.available and (.connected | not) and .connection == ""' <<<"$state" >/dev/null

# An offline NetworkManager state is normal. It must not make `set -e` abort
# the shared status payload, because that also takes the audio panel down. An
# interrupted write may leave an empty notification cache; it is optional too.
export MOCK_NMCLI_EXIT=10
mkdir -p "$XDG_STATE_HOME/seele-shell"
: >"$XDG_STATE_HOME/seele-shell/notification-times.json"
state=$(bash -c 'source "$1"; status' _ "$work/functions.sh")
jq -e '
  .connection == "Disconnected"
  and .audioDevices != null
  and .volume != null
  and .cameraDevices == [{name:"Fixture Camera",device:"/dev/video0"}]
' <<<"$state" >/dev/null

SEELE_CONTROL_NO_STATUS=1 bash "$control" tailscale down
SEELE_CONTROL_NO_STATUS=1 bash "$control" proton-vpn connect
SEELE_CONTROL_NO_STATUS=1 bash "$control" proton-vpn disconnect
speedtest=$(SEELE_CONTROL_NO_STATUS=1 bash "$control" speedtest 2>/dev/null)
jq -s -e '
  any(.[]; .phase == "ping")
  and any(.[]; .phase == "download" and .download == 456.78)
  and any(.[]; .phase == "upload" and .upload == 23.45)
' <<<"$speedtest" >/dev/null
jq -e '
  .ping == 12.34 and .download == 456.78 and .upload == 23.45
  and .jitter == 1.23 and .server == "Fixture Server"
' <<<"$(tail -n 1 <<<"$speedtest")" >/dev/null
grep -qx 'tailscale down' "$MOCK_ACTIONS"
grep -qx 'protonvpn connect' "$MOCK_ACTIONS"
grep -qx 'protonvpn disconnect' "$MOCK_ACTIONS"
grep -qx 'speedtest --accept-license --accept-gdpr --format=jsonl --progress=yes --progress-update-interval=250' "$MOCK_ACTIONS"
