{ ... }:
let
  module = {
    boot.plymouth.enable = true;
  };
in
{
  flake.modules.nixos.pm-plymouth = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
