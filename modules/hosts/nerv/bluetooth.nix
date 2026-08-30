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
          # Audio/Video major class, Loudspeaker minor class. iOS routes its
          # output picker on the class a device advertises, and it never offers
          # a Computer-class device as a speaker however complete that device's
          # A2DP sink records are, so the shell's Bluetooth receiver is
          # unreachable from an iPhone without this. BlueZ honours only the
          # major and minor bits here and derives the service bits from the
          # profiles PipeWire actually registers.
          Class = "0x000414";
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
