{ ... }:
let
  module = {
    homebrew.casks = [ "elgato-stream-deck" ];
  };
in
{
  flake.modules.darwin.elgato-stream-deck = module;
}
