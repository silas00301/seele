{ ... }:
let
  module = ({
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };
  });
in
{
  flake.modules.homeManager."atuin" = module;
}
