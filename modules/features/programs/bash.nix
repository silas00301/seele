{ ... }:
let
  module = ({
    programs.bash = {
      enable = true;
      bashrcExtra = ''
        fish
      '';
    };
  });
in
{
  flake.modules.homeManager."bash" = module;
}
