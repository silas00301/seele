{ config, ... }:
let
  modules = config.flake.modules;
  moduleFor =
    programModules:
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = programModules;

      options.username = lib.mkOption { type = lib.types.str; };

      config = {
        environment.systemPackages = with pkgs; [
          vim
          fish
          coreutils
        ];

        nix.settings.experimental-features = "nix-command flakes";
      };
    };
  nixosModule = moduleFor [
    modules.nixos.fish
    modules.nixos.vicinae
    modules.nixos.zsh
  ];
  darwinModule = moduleFor [
    modules.darwin.fish
    modules.darwin.vicinae
    modules.darwin.zsh
  ];
in
{
  flake.modules.nixos = {
    system-common = nixosModule;
    common = nixosModule;
  };
  flake.modules.darwin = {
    system-common = darwinModule;
    common = darwinModule;
  };
}
