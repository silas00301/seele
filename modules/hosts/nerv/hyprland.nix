{ ... }:
let
  module = {
    programs.hyprland.enable = true;
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
in
{
  flake.modules.nixos.nerv-hyprland = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
