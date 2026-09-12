{ ... }:
let
  module =
    {
      config,
      pkgs,
      selfPackages,
      ...
    }:
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
          nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          # The native launcher resolves XDG at execution, including an outer
          # portable launcher's generated configuration directory.
          postBuild =
            let
              manifest = pkgs.writeText "seele-glow-launch.json" (
                builtins.toJSON {
                  version = 1;
                  program = "${pkgs.glow}/bin/glow";
                  environment.GLOW_CONFIG_HOME = "\${GLOW_CONFIG_HOME:-\${XDG_CONFIG_HOME:-$HOME/.config}/glow}";
                }
              );
            in
            ''
              rm "$out/bin/glow"
              makeWrapper ${selfPackages.config-tools}/bin/seele-launch "$out/bin/glow" \
                --add-flags ${pkgs.lib.escapeShellArg (toString manifest)}
            '';
        })
      ];
    };
in
{
  flake.modules.homeManager.glow = module;

  seele.portable.glow = { };
}
