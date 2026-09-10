{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.failure-analysis ];
  };
in
{
  flake.modules.nixos.nerv-failure-analysis = module;
  flake.modules.nixos.nerv = module;
}
