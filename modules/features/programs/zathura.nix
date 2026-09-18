{
  config,
  lib,
  ...
}:
let
  module = (
    { ... }:
    {
      programs.zathura = {
        enable = true;

        options = {
          adjust-open = "best-fit";
          font = "Maple Mono NF CN 11";
          selection-clipboard = "clipboard";
          smooth-scroll = true;
          scroll-step = 80;
          statusbar-home-tilde = true;
          window-title-basename = true;
        };

        # Zathura is already vi-shaped; these only add the half-page scroll and
        # put document navigation on shift, leaving j and k on its line scroll.
        extraConfig = ''
          map u scroll half-up
          map d scroll half-down
          map J navigate next
          map K navigate previous
        '';
      };
    }
  );
in
{
  flake.modules.homeManager."zathura" = module;

  seele.portable.zathura = {
    systems = lib.filter (lib.hasSuffix "-linux") config.systems;
  };
}
