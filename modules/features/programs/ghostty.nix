{
  config,
  lib,
  ...
}:
let
  homeModule = ({
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
  darwinModule = {
    homebrew.casks = [ "ghostty" ];
  };
in
{
  flake.modules.homeManager.ghostty = homeModule;
  flake.modules.darwin.ghostty = darwinModule;

  seele.portable.ghostty = {
    modules = [
      "ghostty"
      "fish"
    ];
    systems = lib.filter (lib.hasSuffix "-linux") config.systems;
  };
}
