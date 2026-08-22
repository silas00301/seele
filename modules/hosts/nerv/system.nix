{ ... }:
let
  module =
    {
      pkgs,
      selfPackages,
      ...
    }:
    {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        selfPackages.codexbar
        wget
        unzip
        sbctl
        wl-clipboard
      ];

      # Keep this at the NixOS release used for the initial installation.
      system.stateVersion = "23.11";
    };
in
{
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
