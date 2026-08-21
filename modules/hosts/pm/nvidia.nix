{ ... }:
let
  module =
    { config, ... }:
    {
      hardware = {
        graphics.enable = true;
        nvidia = {
          modesetting.enable = true;
          open = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
        };
      };

      services.xserver.videoDrivers = [ "nvidia" ];
    };
in
{
  flake.modules.nixos.pm-nvidia = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
