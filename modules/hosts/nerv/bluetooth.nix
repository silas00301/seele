{ ... }:
let
  module = {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;

      settings = {
        General = {
          # Apple accessories that roam between devices reconnect much faster
          # when the adapter stays connectable, and they frequently re-pair on
          # their way back from an iPhone or Mac.
          FastConnectable = true;
          JustWorksRepairing = "always";
          # Exposes the BlueZ battery interfaces the shell reads for the
          # battery menu.
          Experimental = true;
        };
        Policy.AutoEnable = true;
      };
    };
  };
in
{
  flake.modules.nixos.nerv-bluetooth = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
