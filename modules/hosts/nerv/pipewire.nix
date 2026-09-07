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
      # Prepend only the patched Bluetooth plugin; other SPA factories still
      # come from the normal PipeWire package.
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
        wireplumber.extraConfig."51-seele-bluetooth-receiver" = {
          "monitor.bluez.rules" = [
            {
              matches = [ { "node.name" = "~bluez_input.*"; } ];
              actions.update-props = {
                # Otherwise phone streams play directly through the speakers,
                # bypassing the shell's Receive audio switch. The receiver
                # helper alone bridges these inputs to the selected output.
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
