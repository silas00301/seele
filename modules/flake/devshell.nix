{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShellNoCC {
        name = "seele-dev";
        packages = [
          config.formatter
          pkgs.nixd
          pkgs.statix
          pkgs.deadnix
          pkgs.shellcheck
          pkgs.jq
          pkgs.python3
          pkgs.jujutsu
          pkgs.gh
        ];
      };
    };
}
