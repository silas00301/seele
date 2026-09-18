{ config, ... }:
let
  modules = config.flake.modules.homeManager;
  base = { pkgs, ... }: {
    xdg.mimeApps.enable = true;

    home.packages = [
      pkgs.discord
      pkgs.vesktop
      pkgs.jetbrains.idea
      pkgs.jetbrains.webstorm
    ];

    gtk.enable = true;
  };
  profile = {
    imports = [
      modules."1password-linux"
      modules.codex
      modules.comma
      modules.fastfetch
      modules.fish-linux
      modules.ghostty
      modules.hypr
      modules.night-light
      modules.voxtype
      modules.pi
      modules.removable-media
      modules.scratchpad
      modules.shell-ai
      modules.spicetify
      modules.stylix-linux
      modules.trash
      modules.vicinae
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
