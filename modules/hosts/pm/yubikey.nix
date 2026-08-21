{ ... }:
let
  module = {
    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
    };

    programs.yubikey-touch-detector.enable = true;
  };
in
{
  flake.modules.nixos.pm-yubikey = module;
  flake.modules.nixos.pm-system = module;
  flake.modules.nixos.pm = module;
}
