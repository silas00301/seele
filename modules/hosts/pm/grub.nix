{ ... }:
let
  module =
    { pkgs, ... }:
    {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        grub = {
          enable = true;
          configurationLimit = 2;
          devices = [ "nodev" ];
          efiSupport = true;
          useOSProber = true;
        };
      };

      system.activationScripts.cleanStaleGrubCopies.text = ''
        if [ -d /boot/kernels ]; then
          ${pkgs.findutils}/bin/find /boot/kernels -maxdepth 1 -type f -name '*.tmp' -delete
        fi
      '';
    };
in
{
  flake.modules.nixos.pm-grub = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
