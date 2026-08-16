{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base =
    { lib, ... }@args:
    {
      home.homeDirectory = lib.mkForce "/Users/${args.username}";

      programs.fish = {
        shellInit = ''
          eval "$(/opt/homebrew/bin/brew shellenv)" 
        '';
        shellAbbrs.rebuild = {
          position = "command";
          expansion = "nh darwin switch -H wm";
        };
      };
    };
  profile = {
    imports = [
      modules.bitwarden-darwin
      modules.aerospace
      modules.janky-borders
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
