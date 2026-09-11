{ ... }:
{
  flake.modules.homeManager.middle-click =
    { config, lib, ... }:
    {
      # These are toolkit settings, not a compositor-wide input filter.
      gtk.gtk3.extraConfig.gtk-enable-primary-paste = false;
      gtk.gtk4.extraConfig.gtk-enable-primary-paste = false;
      dconf.settings."org/gnome/desktop/interface".gtk-enable-primary-paste = false;

      programs.zen-browser.policies.Preferences = lib.mkIf config.programs.zen-browser.enable (
        builtins.mapAttrs
          (_: value: {
            Value = value;
            Status = "locked";
          })
          {
            "general.autoScroll" = true;
            "middlemouse.paste" = false;
            "middlemouse.contentLoadURL" = false;
          }
      );
    };
}
