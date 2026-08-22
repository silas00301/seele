{ ... }:
let
  module = {
    hardware.bluetooth.enable = true;
  };
in
{
  flake.modules.nixos.nerv-bluetooth = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
