{ ... }:
let
  module = ({ programs.ripgrep.enable = true; });
in
{
  flake.modules.homeManager."ripgrep" = module;
}
