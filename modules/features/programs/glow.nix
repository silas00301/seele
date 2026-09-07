{ ... }:
let
  module =
    { config, pkgs, ... }:
    {
      catppuccin.glamour.enable = true;

      xdg.configFile."glow/glow.yml".source = (pkgs.formats.yaml { }).generate "glow.yml" {
        style = config.home.sessionVariables.GLAMOUR_STYLE or "dark";
        mouse = true;
        width = 100;
        all = false;
        pager = false;
      };

      home.packages = [
        (pkgs.symlinkJoin {
          name = "glow-seele";
          paths = [ pkgs.glow ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          # Glow's native macOS config directory differs from XDG. Resolve it
          # at launch so the portable wrapper's config tree works there too.
          postBuild = ''
            wrapProgram "$out/bin/glow" \
              --run 'export GLOW_CONFIG_HOME="''${GLOW_CONFIG_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/glow}"'
          '';
        })
      ];
    };
in
{
  flake.modules.homeManager.glow = module;

  seele.portable.glow = { };
}
