{ ... }:
let
  homeModule =
    { catppuccin, ... }:
    {
      catppuccin = {
        enable = catppuccin.enable;
        flavor = catppuccin.flavor;
        accent = catppuccin.accent;
        autoEnable = catppuccin.autoEnable;
        mako.enable = false;
      };
    };
  nixosModule =
    { catppuccin, ... }:
    {
      catppuccin = {
        enable = catppuccin.enable;
        flavor = catppuccin.flavor;
        accent = catppuccin.accent;
        autoEnable = catppuccin.autoEnable;

        limine.enable = true;
        sddm.enable = true;
        tty.enable = true;
        plymouth.enable = true;
      };
    };
in
{
  flake.modules.homeManager.catppuccin = homeModule;
  flake.modules.nixos.catppuccin = nixosModule;
}
