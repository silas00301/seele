{ ... }:
{
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
      palette = lib.importJSON "${config.catppuccin.sources.palette}/palette.json";
      theme =
        flavor:
        let
          c = palette.${flavor}.colors;
        in
        {
          id = "catppuccin-${flavor}";
          name = "Catppuccin ${lib.toSentenceCase flavor}";
          inherit flavor;
          base = c.base.hex;
          mantle = c.mantle.hex;
          crust = c.crust.hex;
          surface = c.surface0.hex;
          overlay = c.overlay0.hex;
          text = c.text.hex;
          subtext = c.subtext0.hex;
          accent = c.${catppuccin.accent}.hex;
          red = c.red.hex;
          green = c.green.hex;
          yellow = c.yellow.hex;
          terminal = map (name: c.${name}.hex) [
            "surface1"
            "red"
            "green"
            "yellow"
            "blue"
            "pink"
            "teal"
            "subtext1"
            "surface2"
            "red"
            "green"
            "yellow"
            "blue"
            "pink"
            "teal"
            "text"
          ];
        };
      package = selfPackages.config-tools;
    in
    {
      home.packages = [ package ];
      home.sessionVariables.SEELE_THEME_STATE = state;
      xdg.configFile."seele-theme/catalog.json".text = builtins.toJSON {
        version = 1;
        default = "catppuccin-${catppuccin.flavor}";
        fontFamily = config.stylix.fonts.monospace.name;
        wallpaper = "/etc/wallpaper/wallpaper.jpg";
        themes = map theme [
          "mocha"
          "macchiato"
          "frappe"
          "latte"
        ];
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
      home.activation.seeleTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run env XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome} \
          XDG_STATE_HOME=${lib.escapeShellArg config.xdg.stateHome} \
          ${package}/bin/seele-theme init
      '';

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
        hl.bind("SUPER + CTRL + SHIFT + T", hl.dsp.exec_cmd("${pkgs.vicinae}/bin/vicinae vicinae://launch/@seele/seele-shell/themes"), { description = "Choose a Seele theme" })
      '';
    };
}
