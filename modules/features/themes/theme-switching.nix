{
  inputs,
  config,
  lib,
  ...
}:
let
  themeSettings = config.seele.catppuccin;
in
{
  perSystem =
    { pkgs, config, ... }:
    lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      checks.theme-presets =
        let
          catalog = pkgs.writeText "seele-theme-catalog-check.json" (
            builtins.toJSON {
              version = 2;
              default = "catppuccin-${themeSettings.flavor}";
              fontFamily = "Seele";
              wallpaper = "/etc/wallpaper/wallpaper.jpg";
              commands = { };
              themes = import ./_theme-switching {
                inherit inputs pkgs;
                catppuccin = themeSettings;
                catppuccinPalette = inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.palette;
              };
            }
          );
        in
        pkgs.runCommand "seele-theme-presets-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${../../../tests/theme-presets.py} ${config.packages.config-tools}/bin/seele-theme ${catalog}
          touch "$out"
        '';
    };

  flake.modules.homeManager.theme-switching =
    {
      catppuccin,
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      state = "${config.xdg.stateHome}/seele-theme";
      themes = import ./_theme-switching {
        inherit inputs pkgs catppuccin;
        catppuccinPalette = config.catppuccin.sources.palette;
      };
      package = selfPackages.config-tools;
    in
    {
      home.packages = [ package ];
      home.sessionVariables.SEELE_THEME_STATE = state;
      xdg.configFile."seele-theme/catalog.json".text = builtins.toJSON {
        version = 2;
        default = "catppuccin-${catppuccin.flavor}";
        fontFamily = config.stylix.fonts.monospace.name;
        wallpaper = "/etc/wallpaper/wallpaper.jpg";
        inherit themes;
        commands = {
          hyprctl = "${pkgs.hyprland}/bin/hyprctl";
          tmux = "${pkgs.tmux}/bin/tmux";
          systemctl = "${pkgs.systemd}/bin/systemctl";
          vicinae = "${pkgs.vicinae}/bin/vicinae";
          gsettings = "${pkgs.glib}/bin/gsettings";
        };
      };
      # The native helper owns only its state directory. Home Manager still
      # owns every application config and this stable theme entry point.
      xdg.configFile."seele-shell/theme.json" = {
        text = lib.mkForce null;
        source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${state}/selection.json");
      };
      home.activation.seeleTheme = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" ] ''
        run env XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome} \
          XDG_STATE_HOME=${lib.escapeShellArg config.xdg.stateHome} \
          ${package}/bin/seele-theme init
      '';

      # One stable theme ID survives launcher restarts and declarative settings
      # reloads. The switcher changes its generated file and asks Vicinae to reload.
      programs.vicinae.settings.theme = {
        light.name = lib.mkForce "seele-current";
        dark.name = lib.mkForce "seele-current";
      };
      xdg.dataFile."vicinae/themes/seele-current.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${state}/current/vicinae.toml";

      catppuccin.ghostty.enable = false;
      programs.ghostty.settings.config-file = [ "?${state}/current/ghostty" ];
      # Import only the generated color sheet, preserving GTK settings/fonts.
      gtk.gtk3.extraCss = lib.mkForce ''@import url("file://${state}/current/gtk.css");'';
      gtk.gtk4.extraCss = lib.mkForce ''@import url("file://${state}/current/gtk.css");'';
      programs.fish.interactiveShellInit = lib.mkAfter ''
        function __seele_theme --on-event fish_prompt
          set -l theme_file "$SEELE_THEME_STATE/current/fish.fish"
          if test -r "$theme_file"
            source "$theme_file"
          end
        end
        __seele_theme
      '';
      programs.tmux.extraConfig = lib.mkAfter ''
        source-file -q ${lib.escapeShellArg "${state}/current/tmux.conf"}
      '';
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        do
          local theme = ${builtins.toJSON "${state}/current/hyprland.lua"}
          local file = io.open(theme, "r")
          if file then
            file:close()
            dofile(theme)
          end
        end
        hl.bind("SUPER + CTRL + SHIFT + T", hl.dsp.exec_cmd("${selfPackages.seele-shell}/bin/seele-shellctl control themes"), { description = "Choose a Seele theme" })
      '';
    };
}
