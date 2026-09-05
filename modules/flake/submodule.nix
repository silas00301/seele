{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      updateSubmodule = pkgs.writeShellApplication {
        name = "update-submodule";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.gawk
          pkgs.jujutsu
          pkgs.nix
        ];
        text = builtins.readFile ./_submodule/update.sh;
      };
    in
    {
      apps.update-submodule = {
        type = "app";
        program = "${updateSubmodule}/bin/update-submodule";
        meta.description = "Update a submodule gitlink in the parent repository";
      };
    };
}
