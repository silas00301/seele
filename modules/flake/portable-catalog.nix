{ config, lib, ... }:
let
  applications = lib.mapAttrsToList (name: app: {
    inherit name;
    inherit (app) binary modules systems;
  }) config.seele.portable;
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      manifest = pkgs.writeText "seele-portable-apps.json" (
        builtins.toJSON { inherit system applications; }
      );
      catalog = pkgs.writeShellApplication {
        name = "seele-portable-apps";
        text = ''
          exec ${pkgs.python3}/bin/python3 ${./_portable/catalog.py} ${manifest} "$@"
        '';
      };
    in
    {
      apps.portable-apps = {
        type = "app";
        program = "${catalog}/bin/seele-portable-apps";
        meta.description = "List configured portable applications and their included features";
      };

      checks.portable-catalog = pkgs.runCommand "portable-catalog-check" { } ''
        ${pkgs.python3}/bin/python3 ${./_portable/test-catalog.py} ${./_portable/catalog.py}
        touch "$out"
      '';
    };
}
