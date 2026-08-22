{ ... }:
let
  module = {
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
in
{
  flake.modules.nixos.nerv-gnupg = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
