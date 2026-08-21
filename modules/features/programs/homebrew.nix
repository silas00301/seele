{ ... }:
let
  module = {
    homebrew.enable = true;
  };
in
{
  flake.modules.darwin.homebrew = module;
}
