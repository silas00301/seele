{ ... }:
let
  module = ./_hardware/configuration.nix;
in
{
  flake.modules.nixos.pm-hardware = module;
  flake.modules.nixos.pm = module;
}
