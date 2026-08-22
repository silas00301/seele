{ config, ... }:
{
  flake.modules.homeManager.nerv.imports = [
    config.flake.modules.homeManager.opencode
    config.flake.modules.homeManager.claude-code
    config.flake.modules.homeManager.seele-shell
  ];
}
