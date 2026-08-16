{ ... }:
let
  module = ({ programs.jq.enable = true; });
in
{
  flake.modules.homeManager."jq" = module;
}
