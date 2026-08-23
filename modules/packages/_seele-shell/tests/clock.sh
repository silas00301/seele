#!/usr/bin/env bash
set -euo pipefail

clock=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export XDG_STATE_HOME=$work/state

result=$($clock list)
jq -e '
  .pinned == []
  and any(.zones[]; .id == "UTC" and .zone == "UTC")
  and any(.zones[]; .id == "PST" and (.aliases | contains("PST")))
  and any(.zones[]; .id == "Europe/London" and .flag == "🇬🇧" and .kind == "city")
' <<<"$result" >/dev/null

$clock pin Europe/London
$clock pin UTC
$clock pin Europe/London
jq -e '. == ["Europe/London", "UTC"]' "$XDG_STATE_HOME/seele-shell/timezone" >/dev/null
jq -e '.pinned == ["Europe/London", "UTC"]' < <($clock list) >/dev/null

$clock unpin Europe/London
jq -e '.pinned == ["UTC"]' < <($clock list) >/dev/null
$clock unpin UTC
[[ ! -e $XDG_STATE_HOME/seele-shell/timezone ]]

mkdir -p "$XDG_STATE_HOME/seele-shell"
printf 'Europe/London\n' >"$XDG_STATE_HOME/seele-shell/timezone"
jq -e '.pinned == ["Europe/London"]' < <($clock list) >/dev/null

if $clock pin Invalid/Timezone 2>/dev/null; then
  printf 'invalid timezones must not be pinned\n' >&2
  exit 1
fi
