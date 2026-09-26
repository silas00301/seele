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

      # Light and dark each keep a preset, and an optional schedule flips the
      # mode at fixed times or at sunrise and sunset. The helper's own loop is
      # the schedule: it wakes at the next boundary, and at least once a
      # minute so a resumed machine, a changed clock or new settings are seen
      # promptly. It acts only when a boundary passes, so a mode chosen by
      # hand holds until the next one, and it sleeps idle while the schedule
      # is off. Reloading applications needs the session, so it runs in it.
      systemd.user.services.seele-theme-auto = {
        Unit = {
          Description = "Switch Seele Themes between light and dark on schedule";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${package}/bin/seele-theme follow";
          # The user manager does not necessarily carry the session's XDG
          # values, and a scheduler reading a different catalog or state than
          # the picker writes would be worse than none.
          Environment = [
            "XDG_CONFIG_HOME=${config.xdg.configHome}"
            "XDG_STATE_HOME=${config.xdg.stateHome}"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

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
        hl.bind("SUPER + CTRL + SHIFT + T", hl.dsp.exec_cmd("${selfPackages.seele-shell}/bin/seele-shellctl themes"), { description = "Choose a Seele theme" })
      '';
    };
}
