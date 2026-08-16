{ ... }:
let
  module = ({
    programs.ghostty = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      settings = {
        background-opacity = 0.9;
        font-family = "Maple Mono NF CN";
        background-blur = true;
        confirm-close-surface = false;
        keybind = [
          "global:cmd+grave_accent=toggle_quick_terminal"
        ];
      };
    };
  });
in
{
  flake.modules.homeManager."ghostty" = module;
}
