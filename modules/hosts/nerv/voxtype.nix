{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.voxtype ];
  };
in
{
  flake.modules.nixos.nerv-voxtype = module;
  flake.modules.nixos.nerv = module;
}
