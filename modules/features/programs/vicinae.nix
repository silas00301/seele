{ ... }:
let
  module = (
    { pkgs, ... }: {
      programs.vicinae = {
        enable = true;
        package = pkgs.vicinae;
        systemd = {
          enable = true;
          autoStart = true;
          environment = {
            USE_LAYER_SHELL = 1;
          };
        };
      };
    }
  );
in
{
  flake.modules.homeManager."vicinae" = module;
}
