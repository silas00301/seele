{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.openlogi ];
  };
in
{
  flake.modules.nixos.nerv-openlogi = module;
  flake.modules.nixos.nerv = module;
}
