{ config, ... }:
let
  modules = config.flake.modules.darwin;
  module = {
    imports = [
      modules.bitwarden
      modules.jetbrains-toolbox
    ];
  };
in
{
  flake.modules.darwin.asuka-system = module;
  flake.modules.darwin.asuka = module;
}
