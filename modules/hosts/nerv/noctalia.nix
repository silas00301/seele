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
  flake.modules.nixos.nerv-noctalia = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
