{ ... }:
let
  module = {
    programs.zsh.enable = true;
  };
in
{
  flake.modules.nixos.nerv-zsh = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
