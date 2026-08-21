{ ... }:
let
  module = {
    # Currently needs manual installation because of an upstream bug.
    homebrew.casks = [ "logi-options+" ];
  };
in
{
  flake.modules.darwin.logi-options = module;
}
