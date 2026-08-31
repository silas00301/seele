{ ... }:
let
  module = ({
    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
      historyWidget.command = "";
    };
  });
in
{
  flake.modules.homeManager."fzf" = module;

  seele.portable.fzf = { };
}
