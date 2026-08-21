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
      };
    };
  systemModule = {
    nix.settings = {
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      ];
    };
  };
in
{
  flake.modules.homeManager.vicinae = homeModule;
  flake.modules.nixos.vicinae = systemModule;
  flake.modules.darwin.vicinae = systemModule;
}
