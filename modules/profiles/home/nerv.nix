{ config, ... }:
{
  flake.modules.homeManager.nerv.imports = [
    config.flake.modules.homeManager.nerv-noctalia
    config.flake.modules.homeManager.opencode
  ];
}
