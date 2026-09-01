{ config, ... }:
let
  modules = config.flake.modules;
  # Determinate Nix turns both of these on by itself, but naming them keeps the
  # requirement in the configuration rather than in the distribution's defaults.
  experimentalFeatures = [
    "nix-command"
    "flakes"
  ];
  moduleFor =
    programModules: nixConfig:
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = programModules;

      options.username = lib.mkOption { type = lib.types.str; };

      config = lib.mkMerge [
        {
          environment.systemPackages = with pkgs; [
            vim
            fish
            coreutils
          ];
        }
        nixConfig
      ];
    };
  nixosModule =
    moduleFor
      [
        modules.nixos.determinate
        modules.nixos.fish
        modules.nixos.vicinae
        modules.nixos.zsh
      ]
      {
        nix.settings.experimental-features = experimentalFeatures;
      };
  darwinModule =
    moduleFor
      [
        modules.darwin.determinate
        modules.darwin.fish
        modules.darwin.vicinae
        modules.darwin.zsh
      ]
      {
        determinateNix.customSettings.experimental-features = experimentalFeatures;
      };
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
