{ ... }:
let
  module =
    { config, ... }:
    {
      networking.networkmanager.enable = true;

      services.tailscale = {
        enable = true;
        disableUpstreamLogging = true;
        extraSetFlags = [
          "--operator=${config.username}"
          "--ssh=false"
        ];
        openFirewall = true;
        useRoutingFeatures = "client";
      };
    };
in
{
  flake.modules.nixos.nerv-networkmanager = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
