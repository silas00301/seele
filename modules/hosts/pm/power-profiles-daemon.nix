{ ... }:
let
  module = {
    services.power-profiles-daemon.enable = true;
  };
in
{
  flake.modules.nixos.pm-power-profiles-daemon = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
