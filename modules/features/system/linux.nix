{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.catppuccin ];
  };
in
{
  flake.modules.nixos.system-linux = module;
  flake.modules.nixos.linux = module;
}
