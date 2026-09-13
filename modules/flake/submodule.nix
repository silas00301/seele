{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      updateSubmodule =
        pkgs.runCommand "update-submodule" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; }
          ''
            mkdir -p "$out/bin"
            makeWrapper ${config.packages.repo-tools}/bin/update-submodule "$out/bin/update-submodule" \
              --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  pkgs.git
                  pkgs.jujutsu
                ]
              }
          '';
    in
    {
      apps.update-submodule = {
        type = "app";
        program = "${updateSubmodule}/bin/update-submodule";
        meta.description = "Update a submodule gitlink in the parent repository";
      };
    };
}
