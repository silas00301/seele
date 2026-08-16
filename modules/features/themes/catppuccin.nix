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
        mako.enable = false;
      };
    }
  );
in
{
  flake.modules.homeManager."catppuccin" = module;
}
