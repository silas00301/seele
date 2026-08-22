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
  flake.modules.nixos.nerv-sddm = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
