{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.bitwarden-desktop
      ];
    }
  );
in
{
  flake.modules.homeManager."bitwarden" = module;
}
