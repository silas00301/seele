{ ... }:
let
  module = ({
    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
      enableFishIntegration = true;
      options = [ "--cmd cd" ];
    };
  });
in
{
  flake.modules.homeManager."zoxide" = module;
}
