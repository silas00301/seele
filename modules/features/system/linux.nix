{ ... }:
let
  module = (
    { catppuccin, ... }:
    {
      catppuccin = {
        enable = catppuccin.enable;
        flavor = catppuccin.flavor;
        accent = catppuccin.accent;
        autoEnable = catppuccin.autoEnable;

        grub.enable = true;
        sddm.enable = true;
        tty.enable = true;
        plymouth.enable = true;
      };
    }
  );
in
{
  flake.modules.nixos."system-linux" = module;
  flake.modules.nixos."linux" = module;
}
