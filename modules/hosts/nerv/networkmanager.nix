{ ... }:
let
  module =
    { config, lib, ... }:
    {
      networking.networkmanager.enable = true;

      home-manager.users.${config.username}.seele.health.providers.tailscale = {
        enable = lib.mkDefault config.services.tailscale.enable;
        name = "Tailscale";
        deadline = 90000;
        setup = "vpn";
        actions = [ "settings" ];
      };

      services.tailscale = {
        enable = true;
        disableUpstreamLogging = true;
        extraSetFlags = [
          "--operator=${config.username}"
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
