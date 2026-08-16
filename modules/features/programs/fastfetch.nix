{ ... }:
let
  module = ({ programs.fastfetch.enable = true; });
in
{
  flake.modules.homeManager."fastfetch" = module;
}
