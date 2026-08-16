{ config, ... }:
{
  flake.modules.homeManager.pm.imports = [ config.flake.modules.homeManager.opencode ];
}
