{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.hermes ];
  };
in
{
  flake.modules.nixos.nerv-hermes = module;
  flake.modules.nixos.nerv = module;
}
