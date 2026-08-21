{ ... }:
let
  module = {
    networking.networkmanager.enable = true;
  };
in
{
  flake.modules.nixos.pm-networkmanager = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
