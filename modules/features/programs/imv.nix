{
  config,
  lib,
  ...
}:
let
  module = (
    { pkgs, ... }:
    let
      copyImage = pkgs.writeShellApplication {
        name = "seele-imv-copy-image";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.imagemagick
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ./_imv/copy-image.sh;
      };
    in
    {
      home.packages = [ pkgs.imv ];

      # imv installs its built-in bindings first and merges the config file over
      # them, so only the vi-shaped additions belong here. The overlay stays on
      # imv's own toggle; configuring its text costs nothing until it is shown.
      xdg.configFile."imv/config".text = ''
        [options]
        overlay_font = Maple Mono NF CN:11
        overlay_text = $imv_current_file [$imv_current_index/$imv_file_count]
        scaling_mode = shrink

        [binds]
        h = prev
        l = next
        k = zoom 1
        j = zoom -1
        <Shift+Y> = exec ${copyImage}/bin/seele-imv-copy-image
        y = exec printf '%s' "$imv_current_file" | ${pkgs.wl-clipboard}/bin/wl-copy
      '';
    }
  );
in
{
  flake.modules.homeManager."imv" = module;

  perSystem =
    { pkgs, ... }:
    {
      checks.imv-copy-image =
        pkgs.runCommand "imv-copy-image-check"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.bash
              pkgs.coreutils
            ];
          }
          ''
            python3 ${./_imv/test-copy-image.py} ${./_imv/copy-image.sh}
            touch "$out"
          '';
    };

  seele.portable.imv = {
    systems = lib.filter (lib.hasSuffix "-linux") config.systems;
  };
}
