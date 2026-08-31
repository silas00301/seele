{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.determinate ];
  };
in
{
  flake.modules.nixos.nerv-determinate = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
