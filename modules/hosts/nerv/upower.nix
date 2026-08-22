{ ... }:
let
  module = {
    services.upower.enable = true;
  };
in
{
  flake.modules.nixos.nerv-upower = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
