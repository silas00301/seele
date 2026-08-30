{ config, ... }:
let
  module = {
    imports = [
      config.flake.modules.nixos.catppuccin
      config.flake.modules.nixos.stylix
    ];
  };
in
{
  flake.modules.nixos.system-linux = module;
  flake.modules.nixos.linux = module;
}
