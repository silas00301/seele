{ ... }:
let
  module = {
    services.desktopManager.plasma6.enable = true;
  };
in
{
  flake.modules.nixos.nerv-plasma = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
