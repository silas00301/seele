{ config, ... }:
let
  module = {
    imports = [
      config.flake.modules.nixos.catppuccin
      config.flake.modules.nixos.cursor
      config.flake.modules.nixos.firmware-updates
      config.flake.modules.nixos.stylix
      config.flake.modules.nixos.foreign-binaries
      config.flake.modules.nixos.disk-health
    ];
  };
in
{
  flake.modules.nixos.system-linux = module;
  flake.modules.nixos.linux = module;
}
