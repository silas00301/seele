#!/usr/bin/env bash
set -euo pipefail

control=${1:?control script required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
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
SH
for mock in "$work/bin/"*; do
  sed -i "1c#!$BASH" "$mock"
done
chmod +x "$work/bin/"*

export PATH="$work/bin:$PATH"
export MOCK_ACTIONS="$work/actions"
export MOCK_TAILSCALE_JSON='{"BackendState":"Running","Self":{"HostName":"fixture-host","TailscaleIPs":["100.64.0.1"]},"CurrentTailnet":{"Name":"fixture.ts.net"},"Peer":{"one":{"Online":true},"two":{"Online":false}}}'
export MOCK_NMCLI='wireguard:Proton VPN DE#1'

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

SEELE_CONTROL_NO_STATUS=1 bash "$control" tailscale down
SEELE_CONTROL_NO_STATUS=1 bash "$control" proton-vpn connect
SEELE_CONTROL_NO_STATUS=1 bash "$control" proton-vpn disconnect
grep -qx 'tailscale down' "$MOCK_ACTIONS"
grep -qx 'protonvpn connect' "$MOCK_ACTIONS"
grep -qx 'protonvpn disconnect' "$MOCK_ACTIONS"
