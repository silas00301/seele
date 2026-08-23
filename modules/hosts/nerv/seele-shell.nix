{ config, ... }:
let
  module = {
    imports = [ config.flake.modules.nixos.seele-shell-agent-status ];
  };
in
{
  flake.modules.nixos.nerv-seele-shell = module;
  flake.modules.nixos.nerv = module;
}
