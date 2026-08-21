{ ... }:
let
  module = {
    services.upower.enable = true;
  };
in
{
  flake.modules.nixos.pm-upower = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
