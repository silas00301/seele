{ ... }:
let
  module = {
    environment.systemPath = [
      "$HOME/Library/Application\\ Support/JetBrains/Toolbox/scripts"
    ];
  };
in
{
  flake.modules.darwin.jetbrains-toolbox = module;
}
