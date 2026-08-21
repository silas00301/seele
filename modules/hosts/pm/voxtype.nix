{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.voxtype ];
  };
in
{
  flake.modules.nixos.pm-voxtype = module;
  flake.modules.nixos.pm = module;
}
