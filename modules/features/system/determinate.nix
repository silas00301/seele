{ inputs, ... }:
let
  nixosModule = {
    imports = [ inputs.determinate.nixosModules.default ];

    determinate.enable = true;

    # Determinate's module repoints the `nixpkgs` registry entry at FlakeHub's
    # weekly nixpkgs, but only while the entry names no flake of its own.
    # Naming this flake's nixpkgs keeps `nix run nixpkgs#...` on the package set
    # the system was built from instead of a second, silently different one.
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };

  # macOS installs Determinate Nix through Determinate's own graphical
  # installer; this module only hands nix-darwin's Nix configuration over to it.
  # The handover forces `nix.enable` off, so nix-darwin's `nix.settings` and
  # `nix.registry` stop applying and Darwin leaves configure Nix through
  # `determinateNix.customSettings` and `determinateNix.registry` instead, both
  # of which land in files Determinate Nixd includes.
  darwinModule = {
    imports = [ inputs.determinate.darwinModules.default ];

    determinateNix = {
      enable = true;
      registry.nixpkgs.flake = inputs.nixpkgs;
    };
  };
in
{
  flake.modules.nixos.determinate = nixosModule;
  flake.modules.darwin.determinate = darwinModule;
}
