{ ... }:
let
  systemModule = {
    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
    };
  };

  homeModule =
    { config, ... }:
    {
      programs.noctalia = {
        enable = true;
        settings = builtins.replaceStrings [ "@HOME@" ] [ config.home.homeDirectory ] (
          builtins.readFile ./_noctalia/config.toml
        );
      };
    };
in
{
  flake.modules.homeManager.nerv-noctalia = homeModule;
  flake.modules.nixos.nerv-noctalia = systemModule;
  flake.modules.nixos.nerv-system = systemModule;
  flake.modules.nixos.nerv = systemModule;
}
