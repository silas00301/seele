{ ... }:
let
  module = {
    services.printing.enable = false;
  };
in
{
  flake.modules.nixos.pm-printing = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
