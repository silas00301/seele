{ ... }:
let
  module = {
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
    };
  };
in
{
  flake.modules.nixos.pm-noctalia = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
