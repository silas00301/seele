{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.removable-media ];
  };
in
{
  flake.modules.nixos.nerv-removable-media = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
