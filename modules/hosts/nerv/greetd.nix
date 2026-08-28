{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.seele-greeter ];
  };
in
{
  flake.modules.nixos.nerv-greetd = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
