#!/bin/sh

get_artists() {
  echo "$playback" | jq -r '
    [.item.artists[].name | tojson | gsub("\""; "")] | join(", ")
  '
}

get_song() {
  echo "$playback" | jq -r '.item.name | tojson | gsub("\""; "")'
}

playback=$(spotify_player get key playback)

if [[ "$(echo "$playback" | jq .is_playing)" == 'true' ]]; then
  echo "$(get_song) · $(get_artists)"
else
  echo ""
fi
