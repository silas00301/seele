{ ... }:
let
  homeModule =
    { pkgs, ... }:
    {
      programs.vicinae = {
        enable = true;
        package = pkgs.vicinae;
        systemd = {
          enable = true;
          autoStart = true;
          environment.USE_LAYER_SHELL = 1;
        };
        settings.launcher_window = {
          rounding = 8;
        };
      };
    };
  cache = {
    extra-substituters = [ "https://vicinae.cachix.org" ];
    extra-trusted-public-keys = [
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };
  nixosModule = {
    nix.settings = cache;
  };
  # Determinate Nix owns `/etc/nix/nix.conf` on Darwin and switches nix-darwin's
  # own `nix.settings` off with it, so the cache goes through the custom settings
  # Determinate Nixd includes.
  darwinModule = {
    determinateNix.customSettings = cache;
  };
in
{
  flake.modules.homeManager.vicinae = homeModule;
  flake.modules.nixos.vicinae = nixosModule;
  flake.modules.darwin.vicinae = darwinModule;
}
