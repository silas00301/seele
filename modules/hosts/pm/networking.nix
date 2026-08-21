{ ... }:
let
  module = {
    networking.hostName = "pm";
  };
in
{
  flake.modules.nixos.pm-networking = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
