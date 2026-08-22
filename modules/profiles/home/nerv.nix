{ config, ... }:
{
  flake.modules.homeManager.nerv.imports = [ config.flake.modules.homeManager.opencode ];
}
