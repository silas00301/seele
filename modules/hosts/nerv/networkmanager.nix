{ ... }:
let
  module = {
    networking.networkmanager.enable = true;
  };
in
{
  flake.modules.nixos.nerv-networkmanager = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
