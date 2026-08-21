{ ... }:
let
  module = {
    boot.lanzaboote = {
      enable = false;
      pkiBundle = "/var/lib/sbctl";
    };
  };
in
{
  flake.modules.nixos.pm-lanzaboote = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
