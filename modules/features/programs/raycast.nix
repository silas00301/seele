{ ... }:
let
  module = {
    homebrew.casks = [ "raycast" ];
  };
in
{
  flake.modules.darwin.raycast = module;
}
