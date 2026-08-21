{ ... }:
let
  module = {
    programs.zsh.enable = true;
  };
in
{
  flake.modules.nixos.pm-zsh = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
