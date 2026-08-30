{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base =
    { lib, ... }@args:
    {
      home.homeDirectory = lib.mkForce "/Users/${args.username}";
    };
  profile = {
    imports = [
      modules.bitwarden-darwin
      modules.fish-darwin
      modules.aerospace
      base
    ];
  };
in
{
  flake.modules.homeManager = {
    home-darwin = base;
    darwin = profile;
  };
}
