{ ... }:
let
  module = ({
    programs.nushell = {
      enable = true;
    };
  });
in
{
  flake.modules.homeManager."nushell" = module;
}
