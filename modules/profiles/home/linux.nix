{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base = { pkgs, ... }: {
    xdg.mimeApps.enable = true;

    home.packages = [
      pkgs.codex
      pkgs.discord
      pkgs.vesktop
      pkgs.jetbrains.idea
      pkgs.jetbrains.webstorm
    ];

    gtk.enable = true;

    # programs.hyprlock = {
    #   enable = true;
    # };

    programs.fish.shellAbbrs.rebuild = {
      position = "command";
      expansion = "nh os switch";
    };
  };
  profile = {
    imports = [
      modules."1password"
      modules."1password-linux"
      modules.comma
      modules.fastfetch
      modules.ghostty
      modules.hypr
      modules.pi
      modules.spicetify
      modules.vicinae
      modules.spotifyd
      base
    ];
  };
in
{
  flake.modules.homeManager = {
    home-linux = base;
    linux = profile;
  };
}
