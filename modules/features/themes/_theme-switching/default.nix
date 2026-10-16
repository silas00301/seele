# Evaluate the upstream targets once per curated preset and per registered
# theme folder. Only their generated theme data is used; these isolated homes
# are never built or activated.
{
  inputs,
  pkgs,
  catppuccin,
  catppuccinPalette,
  # The shell's drop-in theme folders, as `mkThemes` registers them: each is
  # checked when it is built, and its catalog entry names the registered
  # document. They follow the presets in the switcher.
  folders ? [ ],
}:
let
  lib = pkgs.lib;
  presets = lib.importJSON ./presets.json;
  catppuccinColors = lib.importJSON "${catppuccinPalette}/palette.json";
  render =
    preset:
    let
      folder = preset ? document;
      generated =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            inputs.stylix.homeModules.stylix
            inputs.nixvim.homeModules.nixvim
            inputs.vicinae.homeManagerModules.default
            inputs.zen-browser.homeModules.beta
            inputs.spicetify-nix.homeManagerModules.default
            {
              home = {
                username = "seele-theme";
                homeDirectory = "/var/empty/seele-theme";
                stateVersion = "24.05";
                enableNixpkgsReleaseCheck = false;
              };
              nix.package = null;
              manual.manpages.enable = false;
              news.display = "silent";
              programs.nixvim.enable = true;
              programs.vicinae.enable = true;
              programs.zen-browser.enable = true;
              programs.spicetify.enable = true;
              stylix = {
                enable = true;
                autoEnable = false;
                # A folder carries its own Base16 palette; a preset names a
                # scheme from the pinned base16-schemes.
                base16Scheme =
                  if folder then
                    {
                      inherit (preset) name palette;
                      slug = preset.id;
                    }
                  else
                    "${pkgs.base16-schemes}/share/themes/${preset.id}.yaml";
                polarity = preset.mode;
                # Keep the configured accent for the existing Catppuccin presets.
                override = lib.optionalAttrs (!folder && lib.hasPrefix "catppuccin-" preset.id) {
                  base0D =
                    lib.removePrefix "#"
                      catppuccinColors.${lib.removePrefix "catppuccin-" preset.id}.colors.${catppuccin.accent}.hex;
                };
                targets = {
                  nixvim = {
                    enable = true;
                    plugin = "mini.base16";
                    fonts.enable = false;
                    opacity.enable = false;
                  };
                  vicinae = {
                    enable = true;
                    fonts.enable = false;
                    opacity.enable = false;
                  };
                  gtk.enable = true;
                  gtksourceview.enable = true;
                  kde.enable = true;
                  qt.enable = true;
                  "zen-browser" = {
                    enable = true;
                    profileNames = [ "default" ];
                    fonts.enable = false;
                    opacity.enable = false;
                  };
                  spicetify.enable = true;
                };
              };
            }
          ];
        }).config;
      launcher = generated.programs.vicinae.themes.stylix;
      kdePackage = lib.findFirst (
        package: lib.hasPrefix "stylix-kde-theme" (package.name or "")
      ) null generated.home.packages;
      kdeScheme = lib.concatStrings (
        lib.filter lib.isString (builtins.split "[^a-zA-Z]" generated.lib.stylix.colors.scheme)
      );
    in
    {
      inherit (preset) id name mode;
      # This is the actual Stylix NixVim target output, not a second Base16 map.
      # A folder's is its own, which Stylix was given unchanged and which the
      # helper requires its registered document to repeat exactly.
      palette =
        if folder then preset.palette else generated.programs.nixvim.plugins.mini.modules.base16.palette;
      vicinaeTheme = toString (
        (pkgs.formats.toml { }).generate "seele-${preset.id}-vicinae.toml" (
          launcher
          // {
            meta = launcher.meta // {
              name = preset.name;
            };
          }
        )
      );
      assets = {
        gtkCss = toString generated.xdg.configFile."gtk-3.0/gtk.css".source;
        gtkSourceView = toString generated.xdg.dataFile."gtksourceview-4/styles/stylix.xml".source;
        zenChrome = pkgs.writeText "seele-${preset.id}-zen-chrome.css" generated.programs.zen-browser.profiles.default.userChrome;
        zenContent = pkgs.writeText "seele-${preset.id}-zen-content.css" generated.programs.zen-browser.profiles.default.userContent;
        spicetify = toString (generated.programs.spicetify.theme.src + /color.ini);
        kvantumConfig =
          toString (lib.head generated.qt.kvantum.themes)
          + "/share/Kvantum/Base16Kvantum/Base16Kvantum.kvconfig";
        kvantumSvg =
          toString (lib.head generated.qt.kvantum.themes) + "/share/Kvantum/Base16Kvantum/Base16Kvantum.svg";
        kdeColors = toString kdePackage + "/share/color-schemes/${kdeScheme}.colors";
      };
    }
    // lib.optionalAttrs folder { inherit (preset) document; };
in
map render (presets ++ folders)
