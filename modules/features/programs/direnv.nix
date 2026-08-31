{ ... }:
let
  module = (
    { pkgs-stable, ... }: {
      programs.direnv = {
        enable = true;
        package = pkgs-stable.direnv;
        nix-direnv.enable = true;
        enableNushellIntegration = true;
      };
    }
  );
in
{
  flake.modules.homeManager."direnv" = module;

  seele.portable.direnv = { };
}
