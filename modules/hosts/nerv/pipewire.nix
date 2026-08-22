{ ... }:
let
  module = {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
in
{
  flake.modules.nixos.nerv-pipewire = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
