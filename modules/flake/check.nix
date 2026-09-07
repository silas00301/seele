{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      check = pkgs.writeShellApplication {
        name = "seele-check";
        # Use the caller's Nix distribution, including Determinate Nix on the
        # managed hosts, instead of adding a second Nix to the environment.
        text = builtins.readFile ./_check/check.sh;
      };
    in
    {
      apps.check = {
        type = "app";
        program = "${check}/bin/seele-check";
        meta.description = "Format and validate Seele, optionally building the native host";
      };

      checks.check-command = pkgs.runCommand "seele-check-command-tests" { } ''
        ${pkgs.python3}/bin/python3 ${./_check/test-check.py} ${./_check/check.sh} ${pkgs.bash}/bin/bash
        touch "$out"
      '';
    };
}
