{ ... }:
let
  module =
    {
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    {
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = with pkgs; [
        (lib.hiPrio (uutils-coreutils.override { prefix = null; }))
        (lib.hiPrio uutils-findutils)
        (lib.hiPrio uutils-diffutils)
        (lib.hiPrio uutils-sed)
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
