{ ... }:
let
  module = {
    services.displayManager = {
      defaultSession = "hyprland";
      sddm = {
        enable = true;
        settings.Users.RememberLastSession = false;
        wayland.enable = true;
      };
    };
  };
in
{
  flake.modules.nixos.pm-sddm = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
