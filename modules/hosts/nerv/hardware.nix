{ ... }:
let
  module = ./_hardware/configuration.nix;
in
{
  flake.modules.nixos.nerv-hardware = module;
  flake.modules.nixos.nerv = module;
}
