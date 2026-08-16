{ ... }:
let
  module = ({ programs.opencode.enable = true; });
in
{
  flake.modules.homeManager."opencode" = module;
}
