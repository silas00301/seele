{ ... }:
let
  module =
    {
      config,
      lib,
      selfPackages,
      ...
    }:
    {
      systemd.user.services.wireplumber.environment.SPA_PLUGIN_DIR = lib.makeSearchPath "lib/spa-0.2" [
        selfPackages.pipewire-nothing
        config.services.pipewire.package
      ];
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.extraConfig."50-seele-bluetooth-reconnect" = {
          "monitor.bluez.rules" = [
            {
              matches = [ { "device.name" = "~bluez_card.*"; } ];
              actions.update-props = {
                "bluez5.auto-connect" = [
                  "a2dp_sink"
                  "hfp_hf"
                  "hsp_hs"
                ];
              };
            }
          ];
        };
        wireplumber.extraConfig."51-seele-bluetooth-receiver" = {
          "monitor.bluez.rules" = [
            {
              matches = [ { "node.name" = "~bluez_input.*"; } ];
              actions.update-props = {
                "bluez5.media-source-role" = "input";
              };
            }
          ];
        };
      };
    };
in
{
  flake.modules.nixos.nerv-pipewire = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
