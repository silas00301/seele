{ pkgs, noctalia, ... }:
let
  wallpaper = "/etc/wallpaper/wallpaper.jpg";
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    # Keep XWayland support compiled in. Runtime enablement is configured below.
    xwayland.enable = true;

    extraConfig = ''
      local mod = "SUPER"

      hl.monitor({
        output = "HDMI-1",
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
          col = {
            active_border = colors.accent,
            inactive_border = colors.base,
          },
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

      hl.curve("macosSpring", {
        type = "spring",
        mass = 1,
        stiffness = 180,
        dampening = 22,
      })

      hl.curve("macosFade", {
        type = "bezier",
        points = {
          { 0.22, 1 },
          { 0.36, 1 },
        },
      })

      hl.curve("macosMove", {
        type = "spring",
        mass = 1,
        stiffness = 300,
        dampening = 32,
      })

      hl.animation({
        leaf = "windowsIn",
        enabled = true,
        speed = 3.5,
        spring = "macosSpring",
        style = "popin 94%",
      })

      hl.animation({
        leaf = "windowsOut",
        enabled = true,
        speed = 3,
        bezier = "macosFade",
        style = "popin 94%",
      })

      hl.animation({
        leaf = "windowsMove",
        enabled = true,
        speed = 2.5,
        spring = "macosMove",
      })

      hl.animation({
        leaf = "fadeIn",
        enabled = true,
        speed = 2.5,
        bezier = "macosFade",
      })

      hl.animation({
        leaf = "fadeOut",
        enabled = true,
        speed = 2,
        bezier = "macosFade",
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

      hl.animation({
        leaf = "fadeDim",
        enabled = true,
        speed = 10,
        bezier = "smoothIn",
      })

      hl.animation({
        leaf = "workspaces",
        enabled = true,
        speed = 6,
        bezier = "default",
      })

      hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
      hl.bind(mod .. " + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })

      hl.bind(mod .. " + Q", hl.dsp.window.close())
      hl.bind(mod .. " + W", hl.dsp.exec_cmd("${pkgs.ghostty}/bin/ghostty"))
      hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("${pkgs.ghostty}/bin/ghostty"))
      hl.bind(mod .. " + B", hl.dsp.exec_cmd("zen"))
      hl.bind(mod .. " + L", hl.dsp.exec_cmd("${pkgs.noctalia}/bin/noctalia msg session lock"))
      hl.bind(mod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))

      hl.bind(mod .. " + F", hl.dsp.window.fullscreen({
        mode = "maximized",
        action = "toggle",
      }))

      hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({
        mode = "fullscreen",
        action = "toggle",
      }))

      hl.bind(
        "SUPER + ALT + CTRL + SHIFT + Q",
        hl.dsp.exec_cmd("${pkgs.hyprshutdown}/bin/hyprshutdown")
      )

      hl.bind("SUPER + CTRL + F12", hl.dsp.exec_cmd("${noctalia}/bin/noctalia msg session lock"))

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
        hl.bind(mod .. " + " .. binding.keys, hl.dsp.focus({
          workspace = binding.workspace,
        }))

        hl.bind(mod .. " + SHIFT + " .. binding.keys, hl.dsp.window.move({
          workspace = binding.workspace,
          follow = true,
        }))
      end

      hl.bind("CTRL + SHIFT + H", hl.dsp.window.swap({ direction = "l" }))
      hl.bind("CTRL + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))
      hl.bind("CTRL + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))
      hl.bind("CTRL + SHIFT + L", hl.dsp.window.swap({ direction = "r" }))

      hl.bind("CTRL + H", hl.dsp.focus({ direction = "l" }))
      hl.bind("CTRL + J", hl.dsp.focus({ direction = "d" }))
      hl.bind("CTRL + K", hl.dsp.focus({ direction = "u" }))
      hl.bind("CTRL + L", hl.dsp.focus({ direction = "r" }))

      hl.bind(mod .. " + SHIFT + H", hl.dsp.window.resize({
        x = -100,
        y = 0,
        relative = true,
      }))

      hl.bind(mod .. " + SHIFT + J", hl.dsp.window.resize({
        x = 0,
        y = 100,
        relative = true,
      }))

      hl.bind(mod .. " + SHIFT + K", hl.dsp.window.resize({
        x = 0,
        y = -100,
        relative = true,
      }))

      hl.bind(mod .. " + SHIFT + L", hl.dsp.window.resize({
        x = 100,
        y = 0,
        relative = true,
      }))

      hl.bind(mod .. " + TAB", hl.dsp.workspace.move({
        monitor = "+1",
      }))

      hl.bind(mod .. " + SHIFT + TAB", hl.dsp.workspace.move({
        monitor = "-1",
      }))

      hl.bind(
        "XF86AudioRaiseVolume",
        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        {
          locked = true,
          repeating = true,
        }
      )

      hl.bind(
        "XF86AudioLowerVolume",
        hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        {
          locked = true,
          repeating = true,
        }
      )

      hl.bind(
        "XF86AudioMute",
        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        { locked = true }
      )

      hl.bind(
        "XF86AudioPlay",
        hl.dsp.exec_cmd("playerctl play-pause"),
        { locked = true }
      )

      hl.bind(
        "XF86AudioPause",
        hl.dsp.exec_cmd("playerctl play-pause"),
        { locked = true }
      )

      hl.bind(
        "XF86AudioNext",
        hl.dsp.exec_cmd("playerctl next"),
        { locked = true }
      )

      hl.bind(
        "XF86AudioPrev",
        hl.dsp.exec_cmd("playerctl previous"),
        { locked = true }
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

      hl.window_rule({
        match = {
          title = "^Vicinae",
        },
        no_anim = true,
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
    '';
  };

  programs.hyprlock = {
    enable = false;

    settings = {
      background = [
        {
          path = wallpaper;
          blur_passes = 3;
          blur_size = 3;
        }
      ];
    };
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
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 360;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };
}
