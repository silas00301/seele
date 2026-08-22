{ ... }:
let
  module = {
    boot.plymouth.enable = true;
  };
in
{
  flake.modules.nixos.nerv-plymouth = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
