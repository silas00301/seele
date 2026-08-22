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
  # Kept as an alternate shell profile. Seele Shell is active; importing these
  # named modules explicitly switches the relevant layer back to Noctalia.
  flake.modules.homeManager.nerv-noctalia = homeModule;
  flake.modules.nixos.nerv-noctalia = systemModule;
}
