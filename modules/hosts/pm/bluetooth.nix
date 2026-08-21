{ ... }:
let
  module = {
    hardware.bluetooth.enable = true;
  };
in
{
  flake.modules.nixos.pm-bluetooth = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
