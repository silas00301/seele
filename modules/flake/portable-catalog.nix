{ config, lib, ... }:
let
  applications = lib.mapAttrsToList (name: app: {
    inherit name;
    inherit (app) binary modules systems;
  }) config.seele.portable;
in
{
  perSystem =
    {
      pkgs,
      system,
      config,
      ...
    }:
    let
      manifest = pkgs.writeText "seele-portable-apps.json" (
        builtins.toJSON { inherit system applications; }
      );
      catalog =
        pkgs.runCommand "seele-portable-apps"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          }
          ''
            mkdir -p "$out/bin"
            makeWrapper ${config.packages.config-tools}/bin/seele-portable-apps "$out/bin/seele-portable-apps" \
              --add-flags ${lib.escapeShellArg (toString manifest)}
          '';
    in
    {
      apps.portable-apps = {
        type = "app";
        program = "${catalog}/bin/seele-portable-apps";
        meta.description = "List configured portable applications and their included features";
      };

      checks.portable-catalog = config.packages.config-tools;
    };
}
