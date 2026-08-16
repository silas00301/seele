{ ... }:
let
  module = ({ programs.bat.enable = true; });
in
{
  flake.modules.homeManager."bat" = module;
}
