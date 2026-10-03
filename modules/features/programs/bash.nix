{ ... }:
let
  module = ({
    programs.bash = {
      enable = true;
      # Home Manager guards initExtra behind its interactive-shell check.
      initExtra = ''
        fish
      '';
    };
  });
in
{
  flake.modules.homeManager."bash" = module;
}
