{ ... }:
let
  module = {
    networking.hostName = "nerv";
  };
in
{
  flake.modules.nixos.nerv-networking = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
