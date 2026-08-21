{ ... }:
let
  module = {
    programs.home-manager.enable = true;
  };
in
{
  flake.modules.homeManager.home-manager = module;
}
