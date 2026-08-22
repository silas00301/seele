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
  flake.modules.nixos.nerv-xserver = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
