{ ... }:
let
  module = {
    system.defaults.finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
      ShowPathbar = true;
      ShowStatusBar = true;
    };
  };
in
{
  flake.modules.darwin.finder = module;
}
