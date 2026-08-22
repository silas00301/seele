{ ... }:
let
  module = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.glib ];
    programs.kdeconnect.enable = true;
  };
in
{
  flake.modules.nixos.nerv-kdeconnect = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
