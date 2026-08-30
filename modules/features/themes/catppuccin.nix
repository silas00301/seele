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
        chromium.enable = false;
        kvantum.enable = false;
        mako.enable = false;
        qt5ct.enable = false;
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
        tty.enable = true;
        plymouth.enable = true;
      };
    };
in
{
  flake.modules.homeManager.catppuccin = homeModule;
  flake.modules.nixos.catppuccin = nixosModule;
}
