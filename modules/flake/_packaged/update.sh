set -euo pipefail

root="$(git rev-parse --show-toplevel)"
codexbar_file="$root/modules/packages/codexbar.nix"
t3code_file="$root/modules/packages/t3code.nix"

codexbar_release="$({
  curl -fsSL 'https://api.github.com/repos/steipete/CodexBar/releases?per_page=20' |
    jq -er 'map(select((.draft | not) and (.prerelease | not)))[0]'
})"
codexbar_version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$codexbar_release")"
codexbar_url="$(jq -er --arg version "$codexbar_version" '
  .assets[] | select(.name == ("CodexBarCLI-v" + $version + "-linux-x86_64.tar.gz")) | .browser_download_url
' <<<"$codexbar_release")"
codexbar_hash="$(nix store prefetch-file --json "$codexbar_url" | jq -er '.hash')"

t3code_release="$({
  curl -fsSL 'https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20' |
    jq -er 'map(select(.prerelease and (.tag_name | contains("-nightly."))))[0]'
})"
t3code_version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$t3code_release")"
t3code_digest="$(jq -er --arg version "$t3code_version" '
  .assets[] | select(.name == ("T3-Code-" + $version + "-x86_64.AppImage")) | .digest | ltrimstr("sha256:")
' <<<"$t3code_release")"
t3code_hash="$(nix hash convert --hash-algo sha256 --from base16 --to sri "$t3code_digest")"

sed -i -E "0,/version = \"[^\"]+\";/s#version = \"[^\"]+\";#version = \"$codexbar_version\";#" "$codexbar_file"
sed -i -E "0,/hash = \"[^\"]+\";/s#hash = \"[^\"]+\";#hash = \"$codexbar_hash\";#" "$codexbar_file"
sed -i -E "0,/version = \"[^\"]+\";/s#version = \"[^\"]+\";#version = \"$t3code_version\";#" "$t3code_file"
sed -i -E "0,/hash = \"[^\"]+\";/s#hash = \"[^\"]+\";#hash = \"$t3code_hash\";#" "$t3code_file"

printf 'Updated CodexBar to %s\n' "$codexbar_version"
printf 'Updated T3 Code nightly to %s\n' "$t3code_version"
