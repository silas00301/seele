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

  # Every user profile this flake evaluates, on a managed host or on a machine
  # a portable application is carried to, agrees that Nix is the system's own.
  # Determinate's module holds `nix.package` at null, so Home Manager can never
  # put a second Nix on `PATH`, and a leaf that tries to configure Nix through
  # Home Manager fails the evaluation instead of writing a user-level `nix.conf`
  # for a Nix that is not the one running.
  homeManagerModule = { lib, ... }: {
    imports = [ inputs.determinate.homeManagerModules.default ];

    # Home Manager's NixOS integration otherwise supplies its own Nix package
    # at the same priority as Determinate's null assignment.
    nix.package = lib.mkForce null;
  };
in
{
  flake.modules.nixos.determinate = nixosModule;
  flake.modules.darwin.determinate = darwinModule;
  flake.modules.homeManager.determinate = homeManagerModule;
}
