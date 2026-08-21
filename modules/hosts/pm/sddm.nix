{ ... }:
let
  module = {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };
in
{
  flake.modules.nixos.pm-sddm = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
