{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base = { pkgs, ... }: {
    home.packages = [
      pkgs.awscli2
      pkgs.spotify
      pkgs.drawio
      pkgs.insomnia
    ];
  };
  profile.imports = [
    modules.aerospace-asuka
    base
  ];
in
{
  flake.modules.homeManager = {
    home-asuka = base;
    asuka = profile;
  };
}
