{ ... }:
let
  module = {
    security.pam.services = {
      login.u2f.enable = true;
      sudo.u2f.enable = true;
    };

    programs.yubikey-touch-detector = {
      enable = true;
      libnotify = false;
      unixSocket = true;
    };
  };
in
{
  flake.modules.nixos.nerv-yubikey = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
