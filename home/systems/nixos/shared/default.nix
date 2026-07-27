{
  pkgs,
  ...
}:
{
  imports = [
    ../shared/programs/1password.nix

    ../../../shared/programs/comma.nix
    ../../../shared/programs/fastfetch.nix
    ../../../shared/programs/ghostty.nix
    ../../../shared/programs/hypr.nix
    ../../../shared/programs/pi.nix
    ../../../shared/programs/spicetify
    ../../../shared/programs/vicinae.nix

    ../../../shared/services/spotifyd.nix
  ];

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

  programs.fish = {
    shellAbbrs = {
      rebuild = {
        position = "command";
        expansion = "nh os switch";
      };
    };
  };
}
