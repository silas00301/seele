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
  flake.modules.nixos.nerv-nvidia = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
