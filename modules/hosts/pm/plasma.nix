{ ... }:
let
  module = {
    services.desktopManager.plasma6.enable = true;
  };
in
{
  flake.modules.nixos.pm-plasma = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
