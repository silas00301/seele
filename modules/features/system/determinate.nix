{ inputs, ... }:
let
  module = {
    imports = [ inputs.determinate.nixosModules.default ];

    determinate.enable = true;

    # Determinate's module repoints the `nixpkgs` registry entry at FlakeHub's
    # weekly nixpkgs, but only while the entry names no flake of its own.
    # Naming this flake's nixpkgs keeps `nix run nixpkgs#...` on the package set
    # the system was built from instead of a second, silently different one.
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };
in
{
  flake.modules.nixos.determinate = module;
}
