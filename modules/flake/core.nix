{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];

  options.dotfiles = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "silash";
      description = "The user managed by every host.";
    };

    catppuccin = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enable = true;
        flavor = "mocha";
        accent = "lavender";
        autoEnable = true;
      };
      description = "Shared Catppuccin settings.";
    };
  };

  config = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    perSystem =
      { system, ... }:
      let
        stable =
          if lib.hasSuffix "-linux" system then inputs.nixpkgs-stable-nixos else inputs.nixpkgs-stable-darwin;
      in
      {
        _module.args.pkgs = lib.mkForce (
          import inputs.nixpkgs {
            inherit system;
            overlays = builtins.attrValues config.flake.overlays;
            config = {
              allowUnfree = true;
              permittedInsecurePackages = [ "electron-39.8.10" ];
            };
          }
        );
        _module.args.pkgs-stable = import stable {
          inherit system;
          config.allowUnfree = true;
        };
      };
  };
}
