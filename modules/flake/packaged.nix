{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      updatePackaged =
        pkgs.runCommand "update-packaged" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; }
          ''
            mkdir -p "$out/bin"
            makeWrapper ${config.packages.repo-tools}/bin/update-packaged "$out/bin/update-packaged" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.git
                  pkgs.curl
                ]
              }
          '';
    in
    {
      apps.update-packaged = {
        type = "app";
        program = "${updatePackaged}/bin/update-packaged";
        meta.description = "Update pinned T3 Code and CodexBar packages";
      };
    };
}
