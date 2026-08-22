{ ... }:
let
  module = {
    homebrew.casks = [ "logi-options+" ];
  };
in
{
  flake.modules.darwin.logi-options = module;
}
