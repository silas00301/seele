#!/usr/bin/env bash
set -euo pipefail

screenshot_script=${1:?usage: test-screenshot.sh SCRIPT [BASE_PATH]}
base_path=${2:-/usr/bin:/bin}
bash_bin=${BASH:?}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/seele-test-command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command_name=${0##*/}
case "$command_name" in
hyprctl)
  case ${1:-} in
  monitors)
    printf '%s\n' '[{"x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0,"activeWorkspace":{"id":1},"specialWorkspace":{"id":0}}]'
    ;;
  clients)
    printf '%s\n' '[{"at":[10,20],"size":[300,200],"workspace":{"id":1},"mapped":true,"hidden":false,"pinned":false}]'
    ;;
  *) exit 2 ;;
  esac
  ;;
jq)
  printf '%s\n' '0,0 1920x1080' '10,20 300x200'
  ;;
hyprpicker)
  exec sleep 3600
  ;;
slurp)
  [[ ${TEST_SLURP_RESULT:-select} != cancel ]] || exit 1
  printf '%s\n' "${TEST_SELECTION:-10,20 300x200}"
  ;;
date)
  printf '%s\n' '2026-09-09_06-00-00'
  ;;
grim)
  output=${!#}
  printf 'fake-png:%s' "${TEST_SELECTION:-10,20 300x200}" >"$output"
  ;;
satty)
  printf '%s\n' "$*" >>"$TEST_STATE/satty.log"
  input=''
  output=''
  while (($#)); do
    case $1 in
    --filename)
      input=$2
      shift 2
      ;;
    --output-filename)
      output=$2
      shift 2
      ;;
    *) shift ;;
    esac
  done
  [[ ${TEST_SATTY_RESULT:-save} != cancel ]] || exit 0
  cp -- "$input" "$output"
  ;;
wl-copy)
  printf '%s\n' "$*" >>"$TEST_STATE/wl-copy.log"
  cat >"$TEST_STATE/clipboard"
  ;;
zenity)
  printf '%s\n' "$*" >>"$TEST_STATE/zenity.log"
  [[ ${TEST_CHOICE:-copy} == upload ]]
  ;;
curl)
  printf '%s\n' "$*" >>"$TEST_STATE/curl.log"
  case ${TEST_CURL_RESULT:-success} in
  success) printf '%s\n' 'https://0x0.st/test-image.png' ;;
  invalid) printf '%s\n' '<html>not a link</html>' ;;
  fail) exit 22 ;;
  *) exit 2 ;;
  esac
  ;;
notify-send)
  printf '%s\n' "$*" >>"$TEST_STATE/notify.log"
  ;;
*)
  printf 'Unexpected test command: %s\n' "$command_name" >&2
  exit 127
  ;;
esac
EOF
chmod +x "$fake_bin/seele-test-command"

for command in curl date grim hyprctl hyprpicker jq notify-send satty slurp wl-copy zenity; do
  ln -s seele-test-command "$fake_bin/$command"
done

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "expected file: $1"
}

assert_absent() {
  [[ ! -e $1 ]] || fail "expected no file: $1"
}

assert_content() {
  local actual
  assert_file "$1"
  actual=$(<"$1")
  [[ $actual == "$2" ]] || fail "unexpected content in $1: $actual"
}

assert_log_contains() {
  local content
  assert_file "$1"
  content=$(<"$1")
  [[ $content == *"$2"* ]] || fail "expected '$2' in $1"
}

assert_log_empty() {
  [[ ! -s $1 ]] || fail "expected empty log: $1"
}

assert_png_count() {
  local expected=$1
  local -a screenshots
  shopt -s nullglob
  screenshots=("$case_home/Pictures/Screenshots/"*.png)
  shopt -u nullglob
  ((${#screenshots[@]} == expected)) ||
    fail "expected $expected screenshots, found ${#screenshots[@]}"
}

prepare_case() {
  local name=$1
  case_home="$test_root/$name/home"
  case_runtime="$test_root/$name/runtime"
  case_state="$test_root/$name/state"
  mkdir -p "$case_home" "$case_runtime" "$case_state"
  : >"$case_state/curl.log"
  : >"$case_state/notify.log"
  : >"$case_state/satty.log"
  : >"$case_state/wl-copy.log"
  : >"$case_state/zenity.log"
}

invoke() {
  local mode=$1
  local choice=${2:-copy}
  local curl_result=${3:-success}
  local satty_result=${4:-save}
  local slurp_result=${5:-select}
  (
    export HOME="$case_home"
    export XDG_RUNTIME_DIR="$case_runtime"
    export TEST_STATE="$case_state"
    export TEST_CHOICE="$choice"
    export TEST_CURL_RESULT="$curl_result"
    export TEST_SATTY_RESULT="$satty_result"
    export TEST_SLURP_RESULT="$slurp_result"
    export PATH="$fake_bin:$base_path"
    "$bash_bin" -euo pipefail "$screenshot_script" "$mode"
  )
}

expected_name='screenshot-2026-09-09_06-00-00.png'
expected_image='fake-png:10,20 300x200'

prepare_case capture
invoke capture
capture_one="$case_home/Pictures/Screenshots/$expected_name"
assert_content "$capture_one" "$expected_image"
assert_content "$case_state/clipboard" "$expected_image"
assert_log_contains "$case_state/wl-copy.log" '--type image/png'
assert_log_empty "$case_state/curl.log"
assert_log_empty "$case_state/zenity.log"
invoke capture
capture_two="$case_home/Pictures/Screenshots/screenshot-2026-09-09_06-00-00-1.png"
assert_content "$capture_two" "$expected_image"
assert_png_count 2

prepare_case annotate
invoke annotate
annotated="$case_home/Pictures/Screenshots/$expected_name"
assert_content "$annotated" "$expected_image"
assert_content "$case_state/clipboard" "$expected_image"
assert_log_contains "$case_state/satty.log" '--actions-on-enter save-to-file'
assert_log_contains "$case_state/satty.log" '--actions-on-escape exit'

prepare_case annotate-cancel
invoke annotate copy success cancel
assert_png_count 0
assert_absent "$case_state/clipboard"

prepare_case upload
invoke upload upload
uploaded="$case_home/Pictures/Screenshots/$expected_name"
assert_content "$uploaded" "$expected_image"
assert_content "$case_state/clipboard" 'https://0x0.st/test-image.png'
assert_log_contains "$case_state/zenity.log" '--ok-label=Upload'
assert_log_contains "$case_state/zenity.log" '--cancel-label=Copy image'
assert_log_contains "$case_state/zenity.log" 'public third-party host'
assert_log_contains "$case_state/zenity.log" '24 hours'
assert_log_contains "$case_state/curl.log" '--proto =https'
assert_log_contains "$case_state/curl.log" '--form-string secret='
assert_log_contains "$case_state/curl.log" '--form-string expires=24'
assert_log_contains "$case_state/curl.log" 'SeeleScreenshot/1.0'
assert_log_contains "$case_state/curl.log" 'https://0x0.st'
assert_log_contains "$case_state/wl-copy.log" '--type text/plain'
assert_log_contains "$case_state/notify.log" 'Screenshot link copied'

prepare_case upload-copy
invoke upload copy
assert_content "$case_state/clipboard" "$expected_image"
assert_log_empty "$case_state/curl.log"
assert_log_contains "$case_state/wl-copy.log" '--type image/png'

prepare_case upload-failure
invoke upload upload fail
assert_content "$case_state/clipboard" "$expected_image"
assert_log_contains "$case_state/notify.log" 'Screenshot upload failed'
assert_log_contains "$case_state/notify.log" 'stayed local'
assert_log_contains "$case_state/wl-copy.log" '--type image/png'

prepare_case upload-invalid
invoke upload upload invalid
assert_content "$case_state/clipboard" "$expected_image"
assert_log_contains "$case_state/notify.log" 'Screenshot upload failed'

prepare_case selection-cancel
invoke capture copy success save cancel
assert_png_count 0
assert_absent "$case_state/clipboard"

printf 'screenshot workflow tests passed\n'
