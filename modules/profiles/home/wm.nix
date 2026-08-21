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
    modules.aerospace-wm
    base
  ];
in
{
  flake.modules.homeManager = {
    home-wm = base;
    wm = profile;
  };
}
