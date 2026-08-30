{ ... }:
let
  module =
    {
      lib,
      pkgs,
      ...
    }:
    let
      setQtTheme = pkgs.writeShellApplication {
        name = "set-brave-qt-theme";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.jq
        ];
        text = ''
          configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
          braveRoot="$configHome/BraveSoftware/Brave-Browser"

          [[ -d "$braveRoot" ]] || exit 0
          [[ ! -e "$braveRoot/SingletonLock" && ! -L "$braveRoot/SingletonLock" ]] || exit 0

          while IFS= read -r -d "" preferences; do
            jq empty "$preferences" >/dev/null 2>&1 || continue
            jq -e '
              (.extensions.theme.system_theme // 0) == 2
              and (.extensions.theme.id // "") == ""
              and (.extensions.theme.pack // "") == ""
            ' "$preferences" >/dev/null && continue

            temporary="$(mktemp --tmpdir="$(dirname "$preferences")" .Preferences.qt.XXXXXX)"
            trap 'rm -f "$temporary"' EXIT
            jq '
              .extensions.theme.system_theme = 2
              | .extensions.theme.id = ""
              | del(.extensions.theme.pack)
            ' "$preferences" > "$temporary"
            chmod --reference="$preferences" "$temporary"
            mv -f "$temporary" "$preferences"
            trap - EXIT
          done < <(find "$braveRoot" -mindepth 2 -maxdepth 2 -type f -name Preferences -print0)
        '';
      };
      braveWithQt = pkgs.brave.overrideAttrs (oldAttrs: {
        preFixup = (oldAttrs.preFixup or "") + ''
          gappsWrapperArgs+=(
            --run ${lib.escapeShellArg "${setQtTheme}/bin/set-brave-qt-theme"}
            --add-flags ${lib.escapeShellArg "--ui-toolkit=qt"}
          )
        '';
      });
    in
    {
      programs.chromium = {
        enable = true;
        package = braveWithQt;
        extensions = [
          {
            id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; # uBlock Origin
          }
          {
            id = "clngdbkpkpeebahjckkjfobafhncgmne"; # Stylus
          }
        ];
        dictionaries = [
          pkgs.hunspellDictsChromium.en_US
          pkgs.hunspellDictsChromium.de_DE
        ];
      };
    };
in
{
  flake.modules.homeManager."brave" = module;
}
