{ ... }:
let
  homeModule =
    {
      catppuccin,
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      package = selfPackages.seele-shell;
      librepodsPackage = package.librepods;
      palette = builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json");
      colors = palette.${catppuccin.flavor}.colors;
      wallpaper = "/etc/wallpaper/wallpaper.jpg";
    in
    {
      catppuccin.hyprlock.enable = lib.mkForce false;

      home.packages = [
        package
        librepodsPackage
      ];
      home.file = {
        ".local/share/vicinae/extensions/seele-shell".source =
          "${package}/share/vicinae/extensions/seele-shell";
        "${config.programs.pi-coding-agent.configDir}/extensions/seele-shell-status.ts".source =
          "${package}/share/seele-shell/pi-status.ts";
      };

      xdg.configFile."opencode/plugins/seele-shell-status.ts".source =
        "${package}/share/seele-shell/opencode-status.ts";
      xdg.configFile."seele-shell/theme.json".text = builtins.toJSON {
        inherit wallpaper;
        fontFamily = "Maple Mono NF CN";
        base = colors.base.hex;
        mantle = colors.mantle.hex;
        surface = colors.surface0.hex;
        overlay = colors.overlay0.hex;
        text = colors.text.hex;
        subtext = colors.subtext0.hex;
        accent = colors.${catppuccin.accent}.hex;
        red = colors.red.hex;
        green = colors.green.hex;
        yellow = colors.yellow.hex;
      };

      # librepods writes its own XDG autostart entry, which starts a second
      # instance next to the user service and duplicates its tray icon. Keep a
      # disabled entry in place so the desktop ignores it.
      xdg.configFile."autostart/librepods.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=librepods
          Comment=Managed by the librepods user service
          Exec=true
          Hidden=true
          NoDisplay=true
          X-GNOME-Autostart-enabled=false
          Terminal=false
        '';
      };

      programs.hyprlock = {
        enable = lib.mkForce true;
        settings = {
          general = {
            hide_cursor = true;
            grace = 2;
          };
          input-field = [
            {
              size = "300, 52";
              position = "0, -40";
              monitor = "";
              fade_on_empty = false;
              placeholder_text = "Password";
              fail_text = "Authentication failed";
              outline_thickness = 2;
              outer_color = "rgb(${builtins.substring 1 6 colors.${catppuccin.accent}.hex})";
              inner_color = "rgba(${builtins.substring 1 6 colors.base.hex}dd)";
              font_color = "rgb(${builtins.substring 1 6 colors.text.hex})";
              check_color = "rgb(${builtins.substring 1 6 colors.green.hex})";
              fail_color = "rgb(${builtins.substring 1 6 colors.red.hex})";
              rounding = 14;
            }
          ];
          label = [
            {
              text = "$TIME";
              position = "0, 100";
              font_family = "Maple Mono NF CN";
              font_size = 54;
              color = "rgb(${builtins.substring 1 6 colors.text.hex})";
              halign = "center";
              valign = "center";
            }
            {
              text = "cmd[update:60000] date '+%Y-%m-%d'";
              position = "0, 48";
              font_family = "Maple Mono NF CN";
              font_size = 14;
              color = "rgb(${builtins.substring 1 6 colors.subtext0.hex})";
              halign = "center";
              valign = "center";
            }
          ];
        };
      };
      services = {
        hypridle.enable = lib.mkForce true;
        mako = {
          enable = true;
          settings = {
            anchor = "top-right";
            background-color = "${colors.base.hex}f5";
            border-color = colors.${catppuccin.accent}.hex;
            border-radius = 14;
            border-size = 2;
            default-timeout = 6000;
            font = "Maple Mono NF CN 11";
            icons = true;
            layer = "overlay";
            margin = "38,10,0";
            padding = 14;
            text-color = colors.text.hex;
            width = 380;
            "body~=\"^<html\"".format = "<b>%s</b>";
            # A notification carrying an action is worth acting on, so it waits
            # for the user instead of expiring into the history view.
            "actionable=true".default-timeout = 0;
            "mode=do-not-disturb".invisible = true;
          };
        };
      };

      systemd.user.services = {
        seele-shell = {
          Unit = {
            Description = "Seele desktop shell";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };
          Service = {
            Environment = [
              "QT_QPA_PLATFORMTHEME=gtk3"
              "SEELE_SHELL_WALLPAPER=${wallpaper}"
              "SEELE_SHELL_CODEXBAR=${lib.getExe selfPackages.codexbar}"
              "SEELE_SHELL_PI=${lib.getExe config.programs.pi-coding-agent.package}"
              "SEELE_SHELL_OPENCODE=${lib.getExe config.programs.opencode.package}"
              "SEELE_SHELL_CODEX=${lib.getExe pkgs.codex}"
              "SEELE_SHELL_CLAUDE=${lib.getExe pkgs.claude-code}"
              "SEELE_SHELL_GHOSTTY=${lib.getExe pkgs.ghostty}"
              "SEELE_SHELL_HYPRCTL=${pkgs.hyprland}/bin/hyprctl"
              "SEELE_SHELL_NH=${lib.getExe config.programs.nh.package}"
              "SEELE_SHELL_REPO=${config.programs.nh.flake}"
            ];
            ExecStart = lib.getExe package;
            Restart = "on-failure";
            RestartSec = 1;
          };
          Install.WantedBy = [ "hyprland-session.target" ];
        };

        librepods = {
          Unit = {
            Description = "AirPods controls and ear detection";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };
          Service = {
            ExecStart = "${librepodsPackage}/bin/librepods --hide";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "hyprland-session.target" ];
        };

        hyprpolkitagent = {
          Unit = {
            Description = "Hyprland PolicyKit authentication agent";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "hyprland-session.target" ];
        };
      };

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("${package}/bin/seele-shellctl menu"))
        hl.bind("SUPER + ALT + SPACE", hl.dsp.exec_cmd("${package}/bin/seele-shellctl menu apps"))
        hl.bind("SUPER + A", hl.dsp.exec_cmd("${package}/bin/seele-shellctl agents"))
        hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("${package}/bin/seele-shellctl agent pi"))
        hl.bind("SUPER + C", hl.dsp.exec_cmd("${package}/bin/seele-shellctl center"))
        hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("${package}/bin/seele-shellctl controls"))
        hl.bind("SUPER + K", hl.dsp.exec_cmd("${pkgs.vicinae}/bin/vicinae cmd launch @seele/seele-shell:keybindings"))
      '';
    };
  # Pi and OpenCode publish session state from extensions the Home Manager
  # profile installs. Claude Code and Codex have no extension API but expose the
  # same five lifecycle events through hooks, so both are configured at the
  # system layer, where neither fights the mutable config those tools write for
  # themselves and where Codex trusts the hooks without an approval prompt.
  systemModule =
    { lib, selfPackages, ... }:
    let
      hook = agent: status: "${selfPackages.seele-shell}/bin/seele-agent-hook ${agent} ${status}";
      lifecycle = {
        SessionStart = "input";
        UserPromptSubmit = "working";
        Stop = "input";
        SessionEnd = "end";
      };
    in
    {
      environment.etc = {
        "claude-code/managed-settings.d/50-seele-shell-status.json".text = builtins.toJSON {
          hooks = lib.mapAttrs (_: status: [
            {
              hooks = [
                {
                  type = "command";
                  command = hook "claude" status;
                }
              ];
            }
          ]) (lifecycle // { Notification = "input"; });
        };

        "codex/requirements.toml".text = ''
          [features]
          hooks = true

          [hooks]
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (event: status: ''

            [[hooks.${event}]]

            [[hooks.${event}.hooks]]
            type = "command"
            command = "${hook "codex" status}"
          '') (lifecycle // { PermissionRequest = "input"; })
        );
      };
    };
in
{
  flake.modules.homeManager.seele-shell = homeModule;
  flake.modules.nixos.seele-shell-agent-status = systemModule;
}
