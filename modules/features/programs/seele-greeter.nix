{ ... }:
let
  module =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      username,
      ...
    }:
    let
      inherit (config.catppuccin) accent flavor;
      palette = builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json");
      colors = palette.${flavor}.colors;
      wallpaper = "/etc/wallpaper/wallpaper.jpg";
      greeter = selfPackages.seele-greeter;
      theme = pkgs.writeText "seele-greeter-theme.json" (
        builtins.toJSON {
          inherit username wallpaper;
          userName = username;
          displayName = config.users.users.${username}.description;
          fontFamily = "Maple Mono NF CN";
          base = colors.base.hex;
          mantle = colors.mantle.hex;
          surface = colors.surface0.hex;
          overlay = colors.overlay0.hex;
          text = colors.text.hex;
          subtext = colors.subtext0.hex;
          accent = colors.${accent}.hex;
          red = colors.red.hex;
          yellow = colors.yellow.hex;
          sessionCommand = [
            "${pkgs.uwsm}/bin/uwsm"
            "start"
            "-e"
            "-D"
            "Hyprland"
            "hyprland.desktop"
          ];
        }
      );
      hyprlandConfig = pkgs.writeText "seele-greeter-hyprland.conf" ''
        monitor = , preferred, auto, auto

        env = QT_QPA_PLATFORM,wayland
        env = XDG_CURRENT_DESKTOP,Hyprland

        input {
          kb_layout = de
        }

        general {
          border_size = 0
          gaps_in = 0
          gaps_out = 0
        }

        decoration {
          rounding = 0

          blur {
            enabled = false
          }

          shadow {
            enabled = false
          }
        }

        animations {
          enabled = false
        }

        misc {
          disable_autoreload = true
          disable_hyprland_logo = true
          disable_splash_rendering = true
          force_default_wallpaper = 0
        }

        exec-once = ${greeter}/bin/seele-greeter
      '';
    in
    {
      programs.uwsm.enable = true;

      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          command = lib.escapeShellArgs [
            "${pkgs.dbus}/bin/dbus-run-session"
            "${pkgs.hyprland}/bin/Hyprland"
            "--config"
            hyprlandConfig
          ];
        };
      };

      security.pam.services.login.kwallet = {
        enable = true;
        forceRun = true;
        package = lib.mkDefault pkgs.kdePackages.kwallet-pam;
      };

      # Plasma starts this bridge itself. Hyprland needs it attached to the
      # graphical session so the password cached by pam_kwallet can reach the
      # user's wallet after greetd hands the session to UWSM.
      systemd.user.services.plasma-kwallet-pam = {
        description = "Unlock KWallet from PAM credentials";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session-pre.target" ];
        before = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
          Type = "simple";
          Slice = "background.slice";
          Restart = "no";
        };
      };

      environment.etc."seele-greeter/theme.json".source = theme;
      fonts.packages = [ pkgs.maple-mono.NF-CN ];

      system.checks = [
        (pkgs.runCommandLocal "seele-greeter-hyprland-check" { nativeBuildInputs = [ pkgs.hyprland ]; } ''
          export XDG_RUNTIME_DIR="$TMPDIR/runtime"
          mkdir -m 700 "$XDG_RUNTIME_DIR"
          Hyprland --verify-config --config ${hyprlandConfig}
          touch "$out"
        '')
      ];
    };
in
{
  flake.modules.nixos.seele-greeter = module;
}
