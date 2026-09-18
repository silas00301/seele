{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.noise-suppression ];
  };
in
{
  flake.modules.nixos.nerv-noise-suppression = module;
  flake.modules.nixos.nerv = module;
}
