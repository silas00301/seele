{ ... }:
let
  module = (
    {
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      seeleShell = selfPackages.seele-shell;
      seeleLock = selfPackages.seele-lock;
      screenshot = pkgs.writeShellApplication {
        name = "seele-screenshot";
        runtimeInputs = [
          (pkgs.uutils-coreutils.override { prefix = null; })
          pkgs.grim
          pkgs.hyprland
          pkgs.hyprpicker
          pkgs.jq
          pkgs.satty
          pkgs.slurp
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ./_hypr/screenshot.sh;
      };
      wallpaper = "/etc/wallpaper/wallpaper.jpg";
    in
    {
      home.packages = [ screenshot ];

      wayland.windowManager.hyprland = {
        enable = true;
        configType = "lua";
        systemd.enable = false;

        # Keep XWayland support compiled in. Runtime enablement is configured below.
        xwayland.enable = true;

        extraConfig = ''
          local mod = "SUPER"

          hl.monitor({
            output = "HDMI-A-1",
            mode = "1920x1080@60",
            position = "0x0",
            scale = 1,
          })

          hl.monitor({
            output = "DP-1",
            mode = "2560x1440@144",
            position = "auto-right",
            scale = 1,
          })

          hl.on("hyprland.start", function()
            hl.exec_cmd("${pkgs._1password-gui}/bin/1password --silent")
            hl.exec_cmd("${config.programs.spicetify.spicedSpotify}/bin/spotify")
          end)

          hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
          hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1" })
          hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
          hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })

          hl.config({
            xwayland = {
              enabled = true,
            },

            input = {
              kb_layout = "de",
              follow_mouse = 1,
              sensitivity = 0,
            },

            general = {
              gaps_in = 5,
              gaps_out = 5,
              border_size = 2,
              layout = "master",
            },

            decoration = {
              rounding = 8,
              active_opacity = 1.0,
              inactive_opacity = 1.0,
              blur = {
                enabled = true,
                noise = 0.02,
                size = 10,
                passes = 1,
                vibrancy = 0.3,
              },
            },

            animations = {
              enabled = true,
            },
          })

          hl.curve("overshot", {
            type = "bezier",
            points = {
              { 0.05, 0.9 },
              { 0.1, 1.05 },
            },
          })

          hl.curve("smoothOut", {
            type = "bezier",
            points = {
              { 0.36, 0 },
              { 0.66, -0.56 },
            },
          })

          hl.curve("smoothIn", {
            type = "bezier",
            points = {
              { 0.25, 1 },
              { 0.5, 1 },
            },
          })

          -- hl.animation({
          --   leaf = "windows",
          --   enabled = true,
          --   speed = 5,
          --   bezier = "overshot",
          --   style = "slide",
          -- })

          -- hl.animation({
          --   leaf = "windowsOut",
          --   enabled = true,
          --   speed = 4,
          --   bezier = "smoothOut",
          --   style = "slide",
          -- })

          -- hl.animation({
          --   leaf = "windowsMove",
          --   enabled = true,
          --   speed = 4,
          --   bezier = "default",
          -- })

          -- hl.animation({
          --   leaf = "border",
          --   enabled = true,
          --   speed = 10,
          --   bezier = "default",
          -- })

          -- hl.animation({
          --   leaf = "fade",
          --   enabled = true,
          --   speed = 10,
          --   bezier = "smoothIn",
          -- })

          -- Hyprland's speed is a duration in deciseconds: halve the default 8.
          hl.animation({
            leaf = "global",
            enabled = true,
            speed = 4,
            bezier = "default",
          })

          -- Popup tooltips should appear and disappear immediately.
          hl.animation({
            leaf = "fadePopups",
            enabled = false,
          })

          hl.animation({
            leaf = "fadeDim",
            enabled = true,
            speed = 5,
            bezier = "smoothIn",
          })

          hl.animation({
            leaf = "workspaces",
            enabled = true,
            speed = 3,
            bezier = "default",
          })

          hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), {
            mouse = true,
            description = "Move the focused window",
          })
          hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), {
            mouse = true,
            description = "Resize the focused window",
          })
          hl.bind(mod .. " + ALT + mouse:272", hl.dsp.window.resize(), {
            mouse = true,
            description = "Resize the focused window",
          })

          hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "Close the focused window" })
          hl.bind(mod .. " + W", hl.dsp.exec_cmd("${pkgs.ghostty}/bin/ghostty"), { description = "Open a terminal" })
          hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("${pkgs.ghostty}/bin/ghostty"), { description = "Open a terminal" })
          hl.bind(mod .. " + B", hl.dsp.exec_cmd("${lib.getExe config.programs.zen-browser.package}"), { description = "Open the web browser" })
          hl.bind(mod .. " + L", hl.dsp.exec_cmd("${seeleLock}/bin/seele-lock"), { description = "Lock the session" })
          hl.bind(mod .. " + S", hl.dsp.exec_cmd("${screenshot}/bin/seele-screenshot capture"), { description = "Capture a screenshot" })
          hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("${screenshot}/bin/seele-screenshot annotate"), { description = "Capture and annotate a screenshot" })
          hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating for the focused window" })

          hl.bind(
            mod .. " + F",
            hl.dsp.window.fullscreen({
              mode = "maximized",
              action = "toggle",
            }),
            { description = "Toggle maximized for the focused window" }
          )

          hl.bind(
            mod .. " + SHIFT + F",
            hl.dsp.window.fullscreen({
              mode = "fullscreen",
              action = "toggle",
            }),
            { description = "Toggle fullscreen for the focused window" }
          )

          hl.bind(
            "SUPER + ALT + CTRL + SHIFT + Q",
            hl.dsp.exec_cmd("${pkgs.hyprshutdown}/bin/hyprshutdown"),
            { description = "Open the shutdown menu" }
          )

          hl.bind("SUPER + CTRL + F12", hl.dsp.exec_cmd("${seeleLock}/bin/seele-lock"), { description = "Lock the session" })

          local workspace_keys = {
            { keys = "1", workspace = 1 },
            { keys = "2", workspace = 2 },
            { keys = "3", workspace = 3 },
            { keys = "4", workspace = 4 },
            { keys = "ALT + 1", workspace = 5 },
            { keys = "ALT + 2", workspace = 6 },
            { keys = "ALT + 3", workspace = 7 },
            { keys = "ALT + 4", workspace = 8 },
            { keys = "CTRL + 1", workspace = 9 },
            { keys = "CTRL + 2", workspace = 10 },
            { keys = "CTRL + 3", workspace = 11 },
            { keys = "CTRL + 4", workspace = 12 },
          }

          for _, binding in ipairs(workspace_keys) do
            hl.bind(
              mod .. " + " .. binding.keys,
              hl.dsp.focus({
                workspace = binding.workspace,
              }),
              { description = "Focus workspace " .. binding.workspace }
            )

            hl.bind(
              mod .. " + SHIFT + " .. binding.keys,
              hl.dsp.window.move({
                workspace = binding.workspace,
                follow = true,
              }),
              { description = "Move the focused window to workspace " .. binding.workspace }
            )
          end

          hl.bind("CTRL + SHIFT + H", hl.dsp.window.swap({ direction = "l" }), { description = "Swap with the window to the left" })
          hl.bind("CTRL + SHIFT + J", hl.dsp.window.swap({ direction = "d" }), { description = "Swap with the window below" })
          hl.bind("CTRL + SHIFT + K", hl.dsp.window.swap({ direction = "u" }), { description = "Swap with the window above" })
          hl.bind("CTRL + SHIFT + L", hl.dsp.window.swap({ direction = "r" }), { description = "Swap with the window to the right" })

          hl.bind("CTRL + H", hl.dsp.focus({ direction = "l" }), { description = "Focus the window to the left" })
          hl.bind("CTRL + J", hl.dsp.focus({ direction = "d" }), { description = "Focus the window below" })
          hl.bind("CTRL + K", hl.dsp.focus({ direction = "u" }), { description = "Focus the window above" })
          hl.bind("CTRL + L", hl.dsp.focus({ direction = "r" }), { description = "Focus the window to the right" })

          hl.bind(
            mod .. " + SHIFT + H",
            hl.dsp.window.resize({
              x = -100,
              y = 0,
              relative = true,
            }),
            { description = "Shrink the focused window horizontally" }
          )

          hl.bind(
            mod .. " + SHIFT + J",
            hl.dsp.window.resize({
              x = 0,
              y = 100,
              relative = true,
            }),
            { description = "Grow the focused window vertically" }
          )

          hl.bind(
            mod .. " + SHIFT + K",
            hl.dsp.window.resize({
              x = 0,
              y = -100,
              relative = true,
            }),
            { description = "Shrink the focused window vertically" }
          )

          hl.bind(
            mod .. " + SHIFT + L",
            hl.dsp.window.resize({
              x = 100,
              y = 0,
              relative = true,
            }),
            { description = "Grow the focused window horizontally" }
          )

          hl.bind(
            mod .. " + TAB",
            hl.dsp.workspace.move({
              monitor = "+1",
            }),
            { description = "Move the workspace to the next monitor" }
          )

          hl.bind(
            mod .. " + SHIFT + TAB",
            hl.dsp.workspace.move({
              monitor = "-1",
            }),
            { description = "Move the workspace to the previous monitor" }
          )

          hl.bind(
            "XF86AudioRaiseVolume",
            hl.dsp.exec_cmd("${seeleShell}/bin/seele-shellctl volume up"),
            {
              locked = true,
              repeating = true,
              description = "Raise the volume",
            }
          )

          hl.bind(
            "XF86AudioLowerVolume",
            hl.dsp.exec_cmd("${seeleShell}/bin/seele-shellctl volume down"),
            {
              locked = true,
              repeating = true,
              description = "Lower the volume",
            }
          )

          hl.bind(
            "XF86AudioMute",
            hl.dsp.exec_cmd("${seeleShell}/bin/seele-shellctl volume mute"),
            { locked = true, description = "Toggle mute" }
          )

          hl.bind(
            "XF86AudioMicMute",
            hl.dsp.exec_cmd("${seeleShell}/bin/seele-shellctl microphone mute"),
            { locked = true, description = "Toggle microphone mute" }
          )

          hl.bind(
            "XF86AudioPlay",
            hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl play-pause"),
            { locked = true, description = "Toggle media playback" }
          )

          hl.bind(
            "XF86AudioPause",
            hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl play-pause"),
            { locked = true, description = "Toggle media playback" }
          )

          hl.bind(
            "XF86AudioNext",
            hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl next"),
            { locked = true, description = "Play the next track" }
          )

          hl.bind(
            "XF86AudioPrev",
            hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl previous"),
            { locked = true, description = "Play the previous track" }
          )

          -- Replaces the removed general.no_border_on_floating option.
          hl.window_rule({
            match = {
              float = true,
            },
            border_size = 0,
          })

          local floating_titles = {
            "^file_progress$",
            "^confirm$",
            "^dialog$",
            "^download$",
            "^notification$",
            "^error$",
            "^splash$",
            "^confirmreset$",
            "^Open File$",
            "^branchdialog$",
            "^Lxappearance$",
            "^Rofi$",
            "^jetbrains-toolbox$",
            "^viewnior$",
            "^feh$",
            "^pavucontrol-qt$",
            "^pavucontrol$",
            "^file-roller$",
          }

          for _, title in ipairs(floating_titles) do
            hl.window_rule({
              match = {
                title = title,
              },
              float = true,
            })
          end

          hl.layer_rule({
            match = {
              namespace = "vicinae",
            },
            no_anim = true,
          })

          -- Shell surfaces update their own state directly. Compositor motion
          -- makes popouts feel detached and can bounce dynamic content.
          hl.layer_rule({
            match = {
              namespace = "^seele-shell-.*$",
            },
            no_anim = true,
          })

          hl.window_rule({
            match = {
              class = "^(com.mitchellh.ghostty)$",
            },
            workspace = "3 silent",
          })

          hl.window_rule({
            match = {
              class = "^(zen-beta|zen)$",
            },
            workspace = "10 silent",
          })

          hl.window_rule({
            match = {
              class = "^(Vesktop|vesktop|Discord|discord)$",
            },
            workspace = "5 silent",
          })

          hl.window_rule({
            match = {
              class = "^(mpv)$",
            },
            idle_inhibit = "focus",
          })

          hl.window_rule({
            match = {
              class = "^(firefox|brave-browser)$",
            },
            idle_inhibit = "fullscreen",
          })

          hl.window_rule({
            match = {
              class = "^(Spotify|spotify)$",
            },
            workspace = "7 silent",
            fullscreen = true,
          })

          hl.window_rule({
            match = {
              title = "^Media viewer$",
            },
            float = true,
          })

          hl.window_rule({
            match = {
              title = "^Volume Control$",
            },
            float = true,
            size = { 800, 600 },
            move = { 75, "monitor_h*0.44" },
          })

          hl.window_rule({
            match = {
              title = "^Picture-in-Picture$",
            },
            float = true,
          })

          -- The AI cockpit's session for changing Seele itself keeps its own
          -- workspace, so a rebuild never buries the terminal running it.
          hl.window_rule({
            match = {
              class = [[^org\.seele\.os-session$]],
            },
            workspace = "9",
          })

          hl.layer_rule({
            match = {
              namespace = "gtk-layer-shell",
            },
            blur = true,
          })

          hl.layer_rule({
            match = {
              namespace = "waybar",
            },
            blur = true,
          })

          -- The shell's bar and panels are translucent so the surface behind
          -- them reads as frosted glass. The wallpaper and the click-away
          -- catcher are left out: one is opaque and the other is empty.
          -- ignore_alpha keeps the blur off transparent pixels, which matters
          -- because the AI cockpit stays mapped while closed and its rounded
          -- corners would otherwise sit on a squared-off pane of glass.
          hl.layer_rule({
            match = {
              namespace = "^seele-shell-(bar|osd|agents|tray-menu|application|calendar|clock|control-center|media|audio|network|vpn|bluetooth|airpods|battery|notifications|camera|session|polkit)$",
            },
            blur = true,
            -- HoverTip uses child PopupWindows, not separate layer surfaces.
            blur_popups = true,
            ignore_alpha = 0.4,
          })
        '';
      };

      services.hyprpaper = {
        enable = false;

        settings = {
          splash = false;

          wallpaper = [
            {
              monitor = "";
              path = wallpaper;
              fit_mode = "cover";
            }
          ];
        };
      };

      services.hypridle = {
        enable = false;

        settings = {
          general = {
            lock_cmd = "${seeleLock}/bin/seele-lock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
          };

          listener = [
            {
              timeout = 1800;
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 1860;
              on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
              on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
            }
          ];
        };
      };
    }
  );
in
{
  flake.modules.homeManager."hypr" = module;
}
