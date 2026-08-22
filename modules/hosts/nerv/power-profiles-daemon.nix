{ ... }:
let
  module = {
    services.power-profiles-daemon.enable = true;
  };
in
{
  flake.modules.nixos.nerv-power-profiles-daemon = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
