#!/usr/bin/env bash
set -euo pipefail

pi_extension=${1:?Pi extension required}
opencode_extension=${2:?OpenCode extension required}
control=${3:?control script required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

esbuild "$pi_extension" --bundle --platform=node --format=cjs \
  --external:@earendil-works/pi-coding-agent --outfile="$work/pi-extension.cjs" >/dev/null
cat >"$work/pi-test.cjs" <<'JS'
const fs = require("node:fs");
const path = require("node:path");
const handlers = new Map();
const extension = require(process.argv[2]).default;
extension({ on(name, handler) { handlers.set(name, handler); } });
const stateFile = path.join(process.env.XDG_STATE_HOME, "seele-shell", "agents", `pi-native-${process.pid}.json`);
const read = () => JSON.parse(fs.readFileSync(stateFile, "utf8"));

(async () => {
  await handlers.get("session_start")({}, {});
  if (read().status !== "input" || read().source !== "native") {
    throw new Error("session_start must report native input state");
  }
  await handlers.get("agent_start")({}, {});
  if (read().status !== "working") throw new Error("agent_start must report working");
  await handlers.get("agent_settled")({}, {});
  if (read().status !== "input") throw new Error("agent_settled must report input");
  await handlers.get("session_shutdown")({}, {});
  if (fs.existsSync(stateFile)) throw new Error("session_shutdown must remove state");
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
JS
XDG_STATE_HOME="$work/state" node "$work/pi-test.cjs" "$work/pi-extension.cjs"

esbuild "$opencode_extension" --bundle --platform=node --format=cjs \
  --external:@opencode-ai/plugin --outfile="$work/opencode-extension.cjs" >/dev/null
cat >"$work/opencode-test.cjs" <<'JS'
const fs = require("node:fs");
const path = require("node:path");
const plugin = require(process.argv[2]).SeeleShellStatus;
const stateFile = path.join(process.env.XDG_STATE_HOME, "seele-shell", "agents", `opencode-native-${process.pid}.json`);
const read = () => JSON.parse(fs.readFileSync(stateFile, "utf8"));

(async () => {
  const hooks = await plugin({});
  if (read().status !== "input" || read().source !== "native") {
    throw new Error("OpenCode startup must report native input state");
  }
  await hooks.event({ event: { type: "session.status", properties: { sessionID: "one", status: { type: "busy" } } } });
  if (read().status !== "working") throw new Error("OpenCode busy session must report working");
  await hooks.event({ event: { type: "permission.asked", properties: { sessionID: "one" } } });
  if (read().status !== "input") throw new Error("OpenCode permission must report input");
  await hooks.event({ event: { type: "permission.replied", properties: { sessionID: "one" } } });
  if (read().status !== "working") throw new Error("OpenCode permission reply must restore working");
  await hooks.event({ event: { type: "session.status", properties: { sessionID: "one", status: { type: "idle" } } } });
  if (read().status !== "input") throw new Error("OpenCode idle session must report input");
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
JS
XDG_STATE_HOME="$work/state" node "$work/opencode-test.cjs" "$work/opencode-extension.cjs"

mkdir -p "$work/state/seele-shell/agents"
cat >"$work/state/seele-shell/agents/pi-native-$$.json" <<JSON
{"agent":"pi","status":"working","pid":$$,"source":"native"}
JSON
cat >"$work/state/seele-shell/agents/pi-zheuristic-$$.json" <<JSON
{"agent":"pi","status":"input","pid":$$,"source":"heuristic"}
JSON
sed '/^case "${1:-status}" in/,$d' "$control" >"$work/functions.sh"
result=$(XDG_STATE_HOME="$work/state" bash -c 'source "$1"; agent_states' _ "$work/functions.sh")
actual=$(jq -r '.pi.status' <<<"$result")
source=$(jq -r '.pi.source' <<<"$result")
[[ $actual == working && $source == native ]] || {
  printf 'native state lost to heuristic fallback: status=%s source=%s\n' "$actual" "$source" >&2
  exit 1
}

cat >"$work/state/seele-shell/agents/pi-native-waiting-$$.json" <<JSON
{"agent":"pi","status":"input","pid":$$,"source":"native"}
JSON
result=$(XDG_STATE_HOME="$work/state" bash -c 'source "$1"; agent_states' _ "$work/functions.sh")
actual=$(jq -r '.pi.status' <<<"$result")
[[ $actual == input ]] || {
  printf 'concurrent input state did not take precedence: status=%s\n' "$actual" >&2
  exit 1
}
