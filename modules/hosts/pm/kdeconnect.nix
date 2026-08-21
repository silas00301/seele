{ ... }:
let
  module = {
    programs.kdeconnect.enable = true;
  };
in
{
  flake.modules.nixos.pm-kdeconnect = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
