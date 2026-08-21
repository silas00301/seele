{ ... }:
let
  module = {
    programs.hyprland.enable = true;
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
in
{
  flake.modules.nixos.pm-hyprland = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
