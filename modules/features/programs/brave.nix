{ inputs, ... }:
let
  module =
    {
      lib,
      pkgs,
      ...
    }:
    let
      desktopTools = inputs.seele-shell.lib.mkNativePackage {
        inherit pkgs;
        name = "desktop-tools";
      };
      setQtTheme = "${desktopTools}/bin/set-brave-qt-theme";
      braveWithQt = pkgs.brave.overrideAttrs (oldAttrs: {
        preFixup = (oldAttrs.preFixup or "") + ''
          gappsWrapperArgs+=(
            --run ${lib.escapeShellArg setQtTheme}
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
