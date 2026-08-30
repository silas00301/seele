{ ... }:
let
  commonHomeTargets = [
    "font-packages"
    "fontconfig"
    "qt"
    "zen-browser"
  ];
  linuxHomeTargets = [
    "gtk"
    "gtksourceview"
    "hyprland"
    "kde"
    "spicetify"
    "x11"
  ];
  nixosTargets = [
    "font-packages"
    "fontconfig"
    "gtk"
    "gtksourceview"
    "qt"
  ];
  darwinTargets = [
    "font-packages"
    "jankyborders"
  ];
  enabledTargets =
    lib: names:
    lib.genAttrs names (_: {
      enable = true;
    });
  sharedModule =
    {
      catppuccin,
      pkgs,
      ...
    }:
    {
      stylix = {
        enable = true;
        autoEnable = false;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-${catppuccin.flavor}.yaml";
        polarity = if catppuccin.flavor == "latte" then "light" else "dark";

        fonts = {
          serif = {
            package = pkgs.noto-fonts;
            name = "Noto Serif";
          };
          sansSerif = {
            package = pkgs.noto-fonts;
            name = "Noto Sans";
          };
          monospace = {
            package = pkgs.maple-mono.NF-CN;
            name = "Maple Mono NF CN";
          };
          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };
  homeModule =
    {
      config,
      lib,
      ...
    }:
    let
      palette = lib.importJSON "${config.catppuccin.sources.palette}/palette.json";
      accent = palette.${config.catppuccin.flavor}.colors.${config.catppuccin.accent}.hex;
    in
    {
      stylix = {
        override.base0D = lib.removePrefix "#" accent;
        targets = lib.recursiveUpdate (enabledTargets lib commonHomeTargets) {
          qt.platform = lib.mkForce "qtct";
          "zen-browser".profileNames = [ "default" ];
        };
      };
    };
  linuxHomeModule =
    { config, lib, ... }:
    {
      stylix.targets = enabledTargets lib linuxHomeTargets;
      qt = {
        qt5ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
        qt6ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
      };
    };
  nixosModule =
    { lib, ... }:
    {
      imports = [ sharedModule ];
      stylix.targets = lib.recursiveUpdate (enabledTargets lib nixosTargets) {
        qt.platform = lib.mkForce "qtct";
      };
    };
  darwinModule =
    { lib, ... }:
    {
      imports = [ sharedModule ];
      stylix.targets = enabledTargets lib darwinTargets;
    };
in
{
  flake.modules.homeManager.stylix = homeModule;
  flake.modules.homeManager.stylix-linux = linuxHomeModule;
  flake.modules.nixos.stylix = nixosModule;
  flake.modules.darwin.stylix = darwinModule;
}
