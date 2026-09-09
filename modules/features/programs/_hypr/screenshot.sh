mode=${1:-capture}
case "$mode" in
capture | annotate | upload) ;;
*)
  printf 'Usage: seele-screenshot [capture|annotate|upload]\n' >&2
  exit 2
  ;;
esac

output_dir="$HOME/Pictures/Screenshots"
mkdir -p "$output_dir"

work_dir=$(mktemp -d --tmpdir="${XDG_RUNTIME_DIR:-/tmp}" seele-screenshot.XXXXXX)
freeze_pid=""
output=""
output_complete=false

cleanup() {
  if [[ -n $freeze_pid ]]; then
    kill "$freeze_pid" 2>/dev/null || true
    wait "$freeze_pid" 2>/dev/null || true
  fi
  if [[ -n $output && $output_complete != true ]]; then
    rm -f -- "$output"
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

monitors=$(hyprctl monitors -j)
clients=$(hyprctl clients -j)

rectangles=$(jq -r --argjson monitors "$monitors" '
    def geometry:
      (.width / .scale | floor) as $width
      | (.height / .scale | floor) as $height
      | if .transform == 1 or .transform == 3 or .transform == 5 or .transform == 7 then
          "\(.x),\(.y) \($height)x\($width)"
        else
          "\(.x),\(.y) \($width)x\($height)"
        end;
    . as $clients
    | ($monitors[] | geometry),
    ([
      $monitors[]
      | .activeWorkspace.id,
        (if .specialWorkspace.id == 0 then empty else .specialWorkspace.id end)
    ]
    | unique) as $visible
    |
    [
      $clients[]
      | select((.mapped // true) and (.hidden != true))
      | select(.pinned == true or (.workspace.id as $id | $visible | index($id) != null))
      | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ]
    | unique[]
' <<<"$clients")

# Hyprpicker holds a snapshot on every output. Grim runs before this process is
# stopped, so the saved pixels are the same ones shown during selection.
hyprpicker -r -z >/dev/null 2>&1 &
freeze_pid=$!
sleep 0.1

selection=$(printf '%s\n' "$rectangles" | slurp 2>/dev/null) || exit 0

# Slurp reports a tiny freeform rectangle for a click. Resolve that point to
# the smallest hinted rectangle, which prefers a window over its monitor.
if [[ $selection =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]] &&
  ((BASH_REMATCH[3] * BASH_REMATCH[4] < 20)); then
  click_x=${BASH_REMATCH[1]}
  click_y=${BASH_REMATCH[2]}
  resolved=""
  resolved_area=0

  while IFS= read -r rectangle; do
    [[ $rectangle =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]] || continue
    rect_x=${BASH_REMATCH[1]}
    rect_y=${BASH_REMATCH[2]}
    rect_width=${BASH_REMATCH[3]}
    rect_height=${BASH_REMATCH[4]}
    ((click_x >= rect_x && click_x < rect_x + rect_width)) || continue
    ((click_y >= rect_y && click_y < rect_y + rect_height)) || continue

    area=$((rect_width * rect_height))
    if [[ -z $resolved ]] || ((area < resolved_area)); then
      resolved="$rectangle"
      resolved_area=$area
    fi
  done <<<"$rectangles"

  [[ -z $resolved ]] || selection=$resolved
fi

stamp=$(date +'%Y-%m-%d_%H-%M-%S')
output="$output_dir/screenshot-$stamp.png"
suffix=1
while ! (set -o noclobber; : >"$output") 2>/dev/null; do
  if [[ ! -e $output ]]; then
    printf 'Unable to reserve screenshot path: %s\n' "$output" >&2
    exit 1
  fi
  output="$output_dir/screenshot-$stamp-$suffix.png"
  ((suffix += 1))
done

capture="$work_dir/capture.png"
grim -g "$selection" "$capture"

kill "$freeze_pid" 2>/dev/null || true
wait "$freeze_pid" 2>/dev/null || true
freeze_pid=""

copy_image() {
  wl-copy --type image/png <"$output"
}

upload_image() {
  local upload_response

  if upload_response=$(
    curl \
      --fail \
      --silent \
      --show-error \
      --connect-timeout 10 \
      --max-time 120 \
      --proto '=https' \
      --tlsv1.2 \
      --user-agent 'SeeleScreenshot/1.0 (+https://github.com/silas00301/seele)' \
      --form "file=@$output;type=image/png" \
      --form-string 'secret=' \
      --form-string 'expires=24' \
      https://0x0.st
  ) && [[ $upload_response =~ ^https://0x0\.st/[A-Za-z0-9._~-]+$ ]]; then
    printf '%s' "$upload_response" | wl-copy --type text/plain
    notify-send \
      --transient \
      'Screenshot link copied' \
      'The public 0x0.st link expires in 24 hours.' || true
    return
  fi

  copy_image
  notify-send \
    --transient \
    --urgency=critical \
    'Screenshot upload failed' \
    'The image stayed local and was copied instead.' || true
}

if [[ $mode == annotate ]]; then
  if ! satty \
    --filename "$capture" \
    --output-filename "$output" \
    --initial-tool arrow \
    --early-exit \
    --actions-on-enter save-to-file \
    --actions-on-escape exit; then
    exit 1
  fi

  # Closing Satty without saving is a cancellation, not an empty screenshot.
  [[ -s $output ]] || exit 0
  output_complete=true
  copy_image
else
  mv -- "$capture" "$output"
  output_complete=true

  if [[ $mode == upload ]] && zenity \
    --question \
    --title='Upload screenshot?' \
    --icon-name=dialog-warning \
    --width=460 \
    --ok-label='Upload' \
    --cancel-label='Copy image' \
    --text=$'This sends the screenshot to 0x0.st, a public third-party host.\n\nAnyone with the secret link can view it for 24 hours. Only upload images that contain no private or sensitive information.'; then
    upload_image
  else
    copy_image
  fi
fi
