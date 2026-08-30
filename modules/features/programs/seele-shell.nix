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
      lockPackage = selfPackages.seele-lock;
      polkitPackage = selfPackages.seele-polkit;
      librepodsPackage = package.librepods;
      palette = builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json");
      colors = palette.${catppuccin.flavor}.colors;
      wallpaper = "/etc/wallpaper/wallpaper.jpg";
    in
    {
      home.packages = [
        package
        lockPackage
        polkitPackage
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
            # Nothing expires on its own. A notification stays current until it
            # is dismissed, so the panel is an inbox rather than a view of the
            # last ten seconds, and every entry in it is still actionable --
            # mako can only invoke an action while a notification is current.
            # The shell retires its own popup on a timer instead.
            default-timeout = 0;
            # History now receives only what was actually dismissed, and the
            # panel offers a 24 hour view of it, which the default of five
            # cannot fill.
            max-history = 100;
            font = "Maple Mono NF CN 11";
            icons = true;
            icon-border-radius = 14;
            # An app's own expiry would retire a notification behind the
            # panel's back, so the timeout above is the only one that counts.
            ignore-timeout = true;
            layer = "overlay";
            margin = "38,10,0";
            padding = 14;
            text-color = colors.text.hex;
            width = 380;
            "body~=\"^<html\"".format = "<b>%s</b>";
            # Mako retains current notifications and their history, while Seele
            # Shell draws the popup so it can provide a real close button.
            "mode=default".invisible = true;
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
              "SEELE_LOCK=${lib.getExe lockPackage}"
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

        tailscale-systray = {
          Unit = {
            Description = "Tailscale system tray";
            PartOf = [ "hyprland-session.target" ];
            After = [ "seele-shell.service" ];
          };
          Service = {
            ExecStart = "${pkgs.tailscale}/bin/tailscale systray";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "hyprland-session.target" ];
        };

        # Replaces hyprpolkitagent, which drew polkit's prompt but dropped the
        # one message that matters here: its `showInfo` handler only printed to
        # stdout, so pam_u2f's touch request never reached the dialog and the
        # `polkit-1` stack's `u2f sufficient` looked like it did nothing.
        # Quickshell's PolkitAgent surfaces the same text as
        # `supplementaryMessage`, so the password field and the token are both
        # visible routes through one PAM conversation.
        seele-polkit = {
          Unit = {
            Description = "Seele PolicyKit authentication agent";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };
          Service = {
            ExecStart = lib.getExe polkitPackage;
            Restart = "on-failure";
            RestartSec = 1;
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
