{ ... }:
let
  module = ({
    programs.eza = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = false;
      icons = "auto";
      git = true;
    };
  });
in
{
  flake.modules.homeManager."eza" = module;
}
