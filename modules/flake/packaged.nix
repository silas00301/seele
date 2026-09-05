{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      updatePackaged = pkgs.writeShellApplication {
        name = "update-packaged";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.gnused
          pkgs.jq
          pkgs.nix
        ];
        text = builtins.readFile ./_packaged/update.sh;
      };
    in
    {
      apps.update-packaged = {
        type = "app";
        program = "${updatePackaged}/bin/update-packaged";
        meta.description = "Update pinned T3 Code and CodexBar packages";
      };
    };
}
