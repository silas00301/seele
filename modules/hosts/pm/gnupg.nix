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
  flake.modules.nixos.pm-gnupg = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
