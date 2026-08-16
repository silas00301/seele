{ ... }:
let
  module = ({
    homebrew.casks = [
      "bitwarden"
    ];

    environment.systemPath = [
      "$HOME/Library/Application\\ Support/JetBrains/Toolbox/scripts"
    ];
  });
in
{
  flake.modules.darwin."wm-system" = module;
  flake.modules.darwin."wm" = module;
}
