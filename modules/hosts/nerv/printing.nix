{ ... }:
let
  module = {
    services.printing.enable = false;
  };
in
{
  flake.modules.nixos.nerv-printing = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
