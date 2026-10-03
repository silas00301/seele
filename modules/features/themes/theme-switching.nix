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
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        theme-presets =
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
      tmuxTheme = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin_tmux.conf";
    in
    {
      home.sessionVariables.SEELE_THEME_STATE = state;
      xdg.configFile."seele-theme/catalog.json".text = builtins.toJSON {
        version = 2;
        default = "catppuccin-${catppuccin.flavor}";
        fontFamily = config.stylix.fonts.monospace.name;
        wallpaper = "/etc/wallpaper/wallpaper.jpg";
        vesktopDir = "${config.xdg.configHome}/vesktop";
        inherit tmuxTheme;
        inherit themes;
        commands = {
          hyprctl = "${pkgs.hyprland}/bin/hyprctl";
          tmux = "${pkgs.tmux}/bin/tmux";
          pgrep = "${pkgs.procps}/bin/pgrep";
          pkill = "${pkgs.procps}/bin/pkill";
          xrdb = "${pkgs.xrdb}/bin/xrdb";
          kdecolors = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme";
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
      # Stylix's Xresources on-change hook reads the linked file. Publish it
      # after Home Manager links the catalog, before that hook runs.
      home.activation.seeleTheme = lib.hm.dag.entryBetween [ "onFilesChange" ] [ "linkGeneration" ] ''
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

      # Spotify's renderer cannot read the private XDG state directory. Its
      # packaged extension reads only the selected Base16 palette on loopback.
      systemd.user.services.seele-theme-palette = {
        Unit = {
          Description = "Serve the selected Seele palette to Spicetify";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${package}/bin/seele-theme serve";
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
      xdg.dataFile = {
        "vicinae/themes/seele-current.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${state}/current/vicinae.toml";
      }
      // lib.listToAttrs (
        map (theme: {
          name = "color-schemes/Seele-${theme.id}.colors";
          value.source = theme.assets.kdeColors;
        }) themes
      )
      //
        lib.genAttrs
          (map (version: "gtksourceview-${version}/styles/stylix.xml") [
            "2.0"
            "3.0"
            "4"
            "5"
          ])
          (_: {
            source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${state}/current/gtksourceview.xml");
          });

      catppuccin.ghostty.enable = false;
      programs.ghostty.settings.config-file = [ "?${state}/current/ghostty" ];
      # Stylix renders each preset during evaluation. Home Manager retains the
      # application entry points while the native helper changes their target.
      xdg.configFile."gtk-3.0/gtk.css" = {
        text = lib.mkForce null;
        source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${state}/current/gtk.css");
      };
      xdg.configFile."gtk-4.0/gtk.css" = {
        text = lib.mkForce null;
        source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${state}/current/gtk.css");
      };
      xdg.configFile."Kvantum/Base16Kvantum/Base16Kvantum.kvconfig".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${state}/current/kvantum.kvconfig"
      );
      xdg.configFile."Kvantum/Base16Kvantum/Base16Kvantum.svg".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${state}/current/kvantum.svg"
      );
      home.file."${config.home.homeDirectory}/.Xresources" = {
        text = lib.mkForce null;
        source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${state}/current/Xresources");
      };
      programs.zen-browser.profiles.default = {
        userChrome = lib.mkForce ''@import url("file://${state}/current/zen-chrome.css");'';
        userContent = lib.mkForce ''@import url("file://${state}/current/zen-content.css");'';
        settings."extensions.activeThemeID" = lib.mkForce "default-theme@mozilla.org";
        settings."zen.view.window.scheme" = lib.mkForce 2;
      };
      # Zen still opens its existing ~/.zen/default profile. The Zen Home
      # Manager module writes to ~/.config/zen/default, so bridge only the
      # theme entry points into the active profile without replacing its
      # profile registry, containers or browser data.
      home.file."${config.home.homeDirectory}/.zen/default/chrome/userChrome.css".source =
        config.lib.file.mkOutOfStoreSymlink "${state}/current/zen-chrome.css";
      home.file."${config.home.homeDirectory}/.zen/default/chrome/userContent.css".source =
        config.lib.file.mkOutOfStoreSymlink "${state}/current/zen-content.css";
      home.file."${config.home.homeDirectory}/.zen/default/user.js".text = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("extensions.activeThemeID", "default-theme@mozilla.org");
        user_pref("zen.view.window.scheme", 2);
      '';
      programs.fish.interactiveShellInit = lib.mkAfter ''
        function __seele_theme --on-event fish_prompt
          set -l theme_file "$SEELE_THEME_STATE/current/fish.fish"
          if test -r "$theme_file"
            source "$theme_file"
          end
        end
        __seele_theme
      '';
      # A foreground `nix build` that ends while this terminal is not the
      # focused window. The helper decides; an SSH session and every other
      # command stay silent. SIL-116's general long-command hook is separate.
      programs.fish.functions.__seele_build_idle_postexec = {
        description = "Notify when a foreground nix build finishes out of sight";
        onEvent = "fish_postexec";
        body = ''
          set -l command_status $status
          if set -q SSH_CONNECTION; or set -q SSH_TTY
            return $command_status
          end
          if not string match -q -r '(^|[[:space:]/])(nix|nix-build)([[:space:]]|$)' -- "$argv[1]"
            return $command_status
          end
          ${package}/bin/seele-build-idle notify \
            --status "$command_status" \
            --pid "$fish_pid" \
            --hyprctl ${pkgs.hyprland}/bin/hyprctl \
            --notify ${pkgs.libnotify}/bin/notify-send \
            -- "$argv[1]"
          return $command_status
        '';
      };
      programs.tmux.extraConfig = lib.mkAfter ''
        source-file -q ${lib.escapeShellArg "${state}/current/tmux.conf"}
        source-file -q ${lib.escapeShellArg tmuxTheme}
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
