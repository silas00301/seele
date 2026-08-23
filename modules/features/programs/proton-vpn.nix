{ ... }:
{
  flake.modules.homeManager.proton-vpn = { pkgs, ... }: {
    home.packages = [
      pkgs.proton-vpn
      pkgs.proton-vpn-cli
    ];
  };
}
