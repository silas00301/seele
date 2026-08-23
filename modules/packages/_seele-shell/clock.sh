#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/seele-shell
pin_file=$state_dir/timezone
zoneinfo_dir=${TZDIR:-/etc/zoneinfo}

zones() {
  cat <<'EOF'
UTC|UTC|Coordinated Universal Time||UTC GMT Z|abbreviation
PST|America/Los_Angeles|Pacific Time||PST PDT|abbreviation
MST|America/Denver|Mountain Time||MST MDT|abbreviation
CST|America/Chicago|Central Time||CST CDT|abbreviation
EST|America/New_York|Eastern Time||EST EDT|abbreviation
CET|Europe/Berlin|Central European Time||CET CEST|abbreviation
JST|Asia/Tokyo|Japan Standard Time||JST|abbreviation
Europe/Berlin|Europe/Berlin|Berlin|🇩🇪|Germany CET CEST|city
Europe/London|Europe/London|London|🇬🇧|United Kingdom UK GMT BST|city
Europe/Paris|Europe/Paris|Paris|🇫🇷|France CET CEST|city
America/Los_Angeles|America/Los_Angeles|Los Angeles|🇺🇸|US USA Pacific PST PDT|city
America/Denver|America/Denver|Denver|🇺🇸|US USA Mountain MST MDT|city
America/Chicago|America/Chicago|Chicago|🇺🇸|US USA Central CST CDT|city
America/New_York|America/New_York|New York|🇺🇸|US USA Eastern EST EDT|city
America/Toronto|America/Toronto|Toronto|🇨🇦|Canada Eastern EST EDT|city
America/Sao_Paulo|America/Sao_Paulo|São Paulo|🇧🇷|Brazil BRT|city
Asia/Dubai|Asia/Dubai|Dubai|🇦🇪|United Arab Emirates UAE GST|city
Asia/Kolkata|Asia/Kolkata|Kolkata|🇮🇳|India IST|city
Asia/Singapore|Asia/Singapore|Singapore|🇸🇬|SGT|city
Asia/Tokyo|Asia/Tokyo|Tokyo|🇯🇵|Japan JST|city
Asia/Seoul|Asia/Seoul|Seoul|🇰🇷|South Korea KST|city
Australia/Sydney|Australia/Sydney|Sydney|🇦🇺|Australia AEST AEDT|city
Pacific/Auckland|Pacific/Auckland|Auckland|🇳🇿|New Zealand NZST NZDT|city
EOF
}

resolve_id() {
  local wanted=${1:-}
  zones | awk -F '|' -v wanted="$wanted" '
    BEGIN { wanted = tolower(wanted) }
    tolower($1) == wanted { print $1; found = 1; exit }
    tolower($2) == wanted && fallback == "" { fallback = $1 }
    END { if (!found && fallback != "") print fallback }
  '
}

pinned_ids() {
  local legacy
  if [[ ! -f $pin_file ]]; then
    printf '[]'
  elif jq -e 'type == "array"' "$pin_file" >/dev/null 2>&1; then
    jq -c 'reduce (.[] | strings) as $id ([]; if index($id) then . else . + [$id] end)' "$pin_file"
  else
    legacy=$(resolve_id "$(<"$pin_file")")
    jq -cn --arg id "$legacy" 'if $id == "" then [] else [$id] end'
  fi
}

write_pins() {
  local pins=$1 temp
  if [[ $(jq 'length' <<<"$pins") == 0 ]]; then
    rm -f "$pin_file"
    return
  fi
  mkdir -p "$state_dir"
  temp=$(mktemp "${pin_file}.XXXXXX")
  printf '%s\n' "$pins" >"$temp"
  mv "$temp" "$pin_file"
}

list() {
  local pinned id zone label flag aliases kind timezone clock day abbreviation offset
  pinned=$(pinned_ids)

  zones_json=$(
    while IFS='|' read -r id zone label flag aliases kind; do
      if [[ $zone == */* ]]; then
        [[ -f $zoneinfo_dir/$zone ]] || continue
        timezone=:$zoneinfo_dir/$zone
      else
        timezone=$zone
      fi
      IFS='|' read -r clock day abbreviation offset < <(TZ="$timezone" date '+%H:%M|%a %d %b|%Z|%z')
      jq -cn \
        --arg id "$id" \
        --arg zone "$zone" \
        --arg label "$label" \
        --arg flag "$flag" \
        --arg aliases "$aliases" \
        --arg kind "$kind" \
        --arg time "$clock" \
        --arg day "$day" \
        --arg abbreviation "$abbreviation" \
        --arg offset "$offset" \
        '{id:$id, zone:$zone, label:$label, flag:$flag, aliases:$aliases, kind:$kind, time:$time, day:$day, abbreviation:$abbreviation, offset:$offset}'
    done < <(zones) | jq -s .
  )

  jq -cn --argjson pinned "$pinned" --argjson zones "$zones_json" '{pinned:$pinned, zones:$zones}'
}

pin() {
  local id pins
  id=$(resolve_id "${1:-}")
  if [[ -z $id ]]; then
    printf 'Unknown timezone: %s\n' "${1:-}" >&2
    exit 2
  fi
  pins=$(pinned_ids)
  write_pins "$(jq -c --arg id "$id" 'if index($id) then . else . + [$id] end' <<<"$pins")"
}

unpin() {
  local id pins
  id=$(resolve_id "${1:-}")
  if [[ -z $id ]]; then
    printf 'Unknown timezone: %s\n' "${1:-}" >&2
    exit 2
  fi
  pins=$(pinned_ids)
  write_pins "$(jq -c --arg id "$id" 'map(select(. != $id))' <<<"$pins")"
}

case ${1:-list} in
  list) list ;;
  pin) pin "${2:-}" ;;
  unpin) unpin "${2:-}" ;;
  *) printf 'Usage: seele-clock [list|pin TIMEZONE|unpin TIMEZONE]\n' >&2; exit 2 ;;
esac
