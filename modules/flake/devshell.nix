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
          pkgs.nodejs_24
          pkgs.python3
          pkgs.jujutsu
          pkgs.gh
        ];
      };
    };
}
