{ ... }:
let
  module = (
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      colors =
        (builtins.fromJSON (builtins.readFile "${config.catppuccin.sources.palette}/palette.json"))
        .${config.catppuccin.flavor}.colors;
      zjstatusColors = lib.concatStringsSep "\n                " (
        lib.mapAttrsToList (name: color: "color_${name} \"${color.hex}\"") colors
      );
      makeKeyBindings =
        keyBindings:
        let
          convertKey = key: "bind \"${key}\"";
        in
        lib.attrsets.mapAttrs' (key: value: {
          name = convertKey key;
          value = value;
        }) keyBindings;
    in
    {
      programs.zellij = {
        enable = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        attachExistingSession = true;
        settings = {
          show_startup_tips = false;
          default_shell = "fish";
          ui.pane_frames.rounded_corners = true;
          keybinds = {
            normal = {
              "bind \"Ctrl 1\"" = {
                GoToTab = 1;
              };
              "bind \"Ctrl 2\"" = {
                GoToTab = 2;
              };
              "bind \"Ctrl 3\"" = {
                GoToTab = 3;
              };
              "bind \"Ctrl 4\"" = {
                GoToTab = 4;
              };
              "bind \"Ctrl 5\"" = {
                GoToTab = 5;
              };
              "bind \"Ctrl 6\"" = {
                GoToTab = 6;
              };
              "bind \"Ctrl 7\"" = {
                GoToTab = 7;
              };
              "bind \"Ctrl 8\"" = {
                GoToTab = 8;
              };
              "bind \"Ctrl 9\"" = {
                GoToTab = 9;
              };
            }
            // makeKeyBindings {
              "Ctrl x" = {
                SwitchToMode = "pane";
              };
              "Ctrl m" = {
                SwitchToMode = "move";
              };
            };
            pane = makeKeyBindings {
              "h" = {
                MoveFocusOrTab = "Left";
              };
              "j" = {
                MoveFocus = "Down";
              };
              "k" = {
                MoveFocus = "Up";
              };
              "l" = {
                MoveFocusOrTab = "Right";
              };
            };
          };
        };
      };
      xdg.configFile."zellij/layouts/default.kdl".text = ''
        layout {
          default_tab_template {
            children
            pane size=1 borderless=true {
              plugin location="file://${pkgs.zjstatus}/bin/zjstatus.wasm" {
                ${zjstatusColors}
                color_accent                "${colors.${config.catppuccin.accent}.hex}"

                format_left                 "{mode}#[bg=$surface0,fg=$accent] {session} #[fg=$surface0]"
                format_center               "{tabs}"
                format_right                "{pipe_current_cmd}{datetime}"
                format_space                ""
                                                                                         
                border_enabled              "true"
                border_char                 "─"
                border_format               "{char}"
                border_position             "top"
                                                                                 
                hide_frame_for_single_pane  "true"
                                                                                 
                mode_normal                 "#[bg=$accent,fg=$crust,bold] NORMAL #[bg=$surface0,fg=$accent]"
                mode_tmux                   "#[bg=$maroon,fg=$crust,bold] TMUX #[bg=$surface0,fg=$maroon]" 
                mode_locked                 "#[bg=$red,fg=$crust,bold] LOCKED #[bg=$surface0,fg=$red]" 
                mode_resize                 "#[bg=$lavender,fg=$crust,bold] RESIZE #[bg=$surface0,fg=$lavender]" 
                mode_pane                   "#[bg=$yellow,fg=$crust,bold] PANE #[bg=$surface0,fg=$yellow]" 
                mode_tab                    "#[bg=$peach,fg=$crust,bold] TAB #[bg=$surface0,fg=$peach]" 
                mode_scroll                 "#[bg=$green,fg=$crust,bold] SCROLL #[bg=$surface0,fg=$green]" 
                mode_enter_search           "#[bg=$teal,fg=$crust,bold] ENTER SEARCH #[bg=$surface0,fg=$teal]" 
                mode_search                 "#[bg=$sapphire,fg=$crust,bold] SEARCH #[bg=$surface0,fg=$sapphire]" 
                mode_rename_tab             "#[bg=$peach,fg=$crust,bold] RENAME TAB #[bg=$surface0,fg=$peach]" 
                mode_rename_pane            "#[bg=$yellow,fg=$crust,bold] RENAME PANE #[bg=$surface0,fg=$yellow]" 
                mode_session                "#[bg=$sky,fg=$crust,bold] SESSION #[bg=$surface0,fg=$sky]" 
                mode_move                   "#[bg=$lavender,fg=$crust,bold] MOVE #[bg=$surface0,fg=$lavender]" 
                mode_prompt                 "#[bg=$text,fg=$crust,bold] PROMPT #[bg=$surface0,fg=$text]"  

                tab_normal                  "#[fg=$surface0]#[fg=$text,bg=$surface0] {index} | {name} #[fg=$surface0]"
                tab_normal_fullscreen       "#[fg=$surface0]#[fg=$text,bg=$surface0] {index} | {name} {fullscreen_indicator} #[fg=$surface0]"
                tab_normal_sync             "#[fg=$surface0]#[fg=$text,bg=$surface0] {index} | {name} {sync_indicator} #[fg=$surface0]"

                tab_active                  "#[fg=$accent,bold]#[fg=$crust,bg=$accent,bold] {index} | {name}  #[fg=$accent,bold]"
                tab_active_fullscreen       "#[fg=$accent,bold]#[fg=$crust,bg=$accent,bold] {index} | {name} {fullscreen_indicator} #[fg=$accent,bold]"
                tab_active_sync             "#[fg=$accent,bold]#[fg=$crust,bg=$accent,bold] {index} | {name} {sync_indicator} #[fg=$accent,bold]"

                tab_rename                  "#[fg=$accent,bold]#[fg=$crust,bg=$accent,bold] {index} | {name} #[fg=$accent,bold]"

                tab_sync_indicator          "↹"
                tab_fullscreen_indicator    "⇱"
                tab_floating_indicator      "⬚"

                tab_display_count           "3"

                datetime                    "#[bg=$surface0,fg=$accent]#[bg=$accent,fg=$crust,bold] {format} "
                datetime_format             "%H:%M"
                datetime_timezone           "Europe/Berlin"

                pipe_current_cmd_format     "#[fg=$surface0]#[bg=$surface0,fg=$accent, bold] {output} "
                pipe_current_cmd_rendermode "static"
              }
            }
          }
        }
      '';
    }
  );
in
{
  flake.modules.homeManager."zellij" = module;

  seele.portable.zellij = {
    modules = [
      "zellij"
      "fish"
    ];
  };
}
