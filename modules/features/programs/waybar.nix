{ ... }:
let
  module = (
    { pkgs, ... }:
    {
      programs.waybar = {
        enable = true;
        systemd.enable = true;
        systemd.target = "graphical-session.target";
        style = ''
          * {
            font-family: "Maple Mono NF CN";
            font-size: 14px;
            min-height: 0;
          }

          #waybar {
            background: transparent;
            color: @text;
            margin: 5px 5px;
          }

          #workspaces {
            border-radius: 16px;
            margin: 5px;
            background-color: @surface0;
            margin-left: 1rem;
          }

          #workspaces button {
            color: @lavender;
            border-radius: 16px;
            padding: 0.4rem;
          }

          #workspaces button.active {
            color: @sky;
            border-radius: 16px;
          }

          #workspaces button:hover {
            color: @sapphire;
            border-radius: 16px;
          }

          #window {
            color: @lavender;
            border-radius: 16px;
            padding: 0.5rem 1rem;
            margin: 5px 0;
            background-color: @surface0
          }

          #custom-spotify-status,
          #tray,
          #backlight,
          #clock,
          #battery,
          #pulseaudio,
          #custom-lock,
          #custom-power {
            background-color: @surface0;
            padding: 0.5rem 1rem;
            margin: 5px 0;
          }

          #clock {
            color: @blue;
            border-radius: 0px 16px 16px 0px;
            margin-right: 1rem;
          }

          #battery {
            color: @green;
          }

          #battery.charging {
            color: @green;
          }

          #battery.warning:not(.charging) {
            color: @red;
          }

          #backlight {
            color: @yellow;
          }

          #backlight, #battery {
              border-radius: 0;
          }

          #pulseaudio {
            color: @maroon;
            border-radius: 16px 0px 0px 16px;
            margin-left: 1rem;
          }

          #custom-spotify-status {
            color: @mauve;
            border-radius: 16px;
          }

          #custom-lock {
              border-radius: 16px 0px 0px 16px;
              color: @lavender;
          }

          #custom-power {
              margin-right: 1rem;
              border-radius: 0px 16px 16px 0px;
              color: @red;
          }

          #tray {
            margin-left: 1rem;
            border-radius: 16px;
          }
        '';
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "hyprland/window" ];
            modules-right = [
              # "custom/spotify-status"
              "tray"
              "pulseaudio"
              "clock"
            ];
            tray = {
              icon-size = 21;
              spacing = 10;
            };
            clock = {
              format = "{0:%H:%M} {0:%Y-%m-%d}";
            };
            # "custom/spotify-status" = {
            #   format = "{text}";
            #   return-type = "text";
            #   max-length = 40;
            #   interval = 15;
            #   escape = true;
            #   exec = "cat /tmp/bar/spt-status";
            # };
            pulseaudio = {
              scroll-step = 1;
              format = "{icon} {volume}%";
              format-muted = "󰖁";
              format-icons = {
                default = [
                  "󰕿"
                  "󰖀"
                  "󰕾"
                ];
              };
              on-click = "pavucontrol";
            };
          };
        };
      };
    }
  );
in
{
  flake.modules.homeManager."waybar" = module;
}
