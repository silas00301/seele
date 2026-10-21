# Which wallpaper each output shows for each Seele theme. theme-switching
# writes this into the theme catalog, `seele-theme` resolves it for the theme
# on screen and the shell draws the result per output, so the mapping is
# rebuilt with every generation and nothing the helper saves can outlive it.
#
# For a theme on an output the first image that is set wins: the one mapped to
# that theme on that output, the one mapped to that theme, the theme's own
# image from its folder, the one mapped to that output for the theme's light or
# dark mode, the one mapped to that output, the one mapped to the theme's mode,
# and finally `image`. Light and dark are the theme's own mode, so a dark theme
# worn in light mode keeps a dark wallpaper.
{ lib, ... }:
let
  image = lib.types.path;
  optional =
    description:
    lib.mkOption {
      type = lib.types.nullOr image;
      default = null;
      inherit description;
    };
  # Images for one place, in any mode or for light and dark themes.
  images = lib.types.submodule {
    options = {
      image = optional "The image this output shows for every theme the mapping gives no more particular one.";
      light = optional "The image this output shows for light themes.";
      dark = optional "The image this output shows for dark themes.";
    };
  };
in
{
  options.seele.wallpaper = {
    image = lib.mkOption {
      type = image;
      default = "/etc/wallpaper/wallpaper.jpg";
      description = ''
        The configured wallpaper: what every output shows for a theme that has
        no image of its own and is mapped none below.
      '';
    };

    light = optional "The wallpaper for light themes without an image of their own.";
    dark = optional "The wallpaper for dark themes without an image of their own.";

    outputs = lib.mkOption {
      type = lib.types.attrsOf images;
      default = { };
      example = lib.literalExpression ''
        {
          "DP-1".image = ./wallpapers/wide.jpg;
          "HDMI-A-1" = {
            light = ./wallpapers/side-day.jpg;
            dark = ./wallpapers/side-night.jpg;
          };
        }
      '';
      description = ''
        Images per output, by the name the compositor gives it (`hyprctl
        monitors`), for every theme without an image of its own.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            image = optional "The image this theme shows, in place of its own.";
            outputs = lib.mkOption {
              type = lib.types.attrsOf image;
              default = { };
              description = "The image this theme shows on each named output.";
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          catppuccin-latte.image = ./wallpapers/latte.jpg;
          cyberpunk.outputs."HDMI-A-1" = ./wallpapers/cyberpunk-side.png;
        }
      '';
      description = ''
        Images per theme, by its ID in the theme switcher, for every output or
        per output. These come before the theme's own image.
      '';
    };
  };
}
