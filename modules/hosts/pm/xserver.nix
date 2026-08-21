{ ... }:
let
  module = {
    services.xserver = {
      enable = true;
      xkb = {
        layout = "de";
        variant = "";
      };
    };
  };
in
{
  flake.modules.nixos.pm-xserver = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
