{ ... }:
let
  module = ({
    programs.zsh = {
      enable = true;
      initContent = ''
        fish
      '';
    };
  });
in
{
  flake.modules.homeManager."zsh" = module;
}
