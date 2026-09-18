{ ... }:
let
  module =
    { pkgs, ... }:
    let
      # `rnnoise-plugin` splits its plugin formats across separate outputs and
      # leaves `$out/lib/ladspa` as a compatibility symlink to the `ladspa`
      # one. Naming `$out` would therefore reference the LV2, LXVST and VST3
      # outputs as well, pulling their JUCE and WebKitGTK closure into the
      # system for a filter that draws no interface.
      rnnoise = "${pkgs.rnnoise-plugin.ladspa}/lib/ladspa/librnnoise_ladspa.so";
    in
    {
      # A filter-chain virtual source published beside the hardware microphone,
      # never in place of it. Nothing here writes `default.audio.source` or its
      # configured counterpart, so WirePlumber keeps the device the user last
      # chose and the Seele Shell Audio panel and Vicinae's audio picker list
      # this node like any other microphone, with microphone selection staying
      # exclusive. The capture stream has no fixed target, so it follows an
      # eligible microphone. PipeWire gives both filter endpoints one link
      # group; WirePlumber excludes that group when selecting a capture target,
      # including when the user selects this virtual source as the default.
      services.pipewire.extraConfig.pipewire."99-seele-noise-suppression" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            # An unloadable plugin must degrade to a missing virtual source
            # rather than stop the audio server from starting at all.
            flags = [ "nofail" ];
            args = {
              "node.description" = "Noise Canceling Microphone";
              "media.name" = "Noise Canceling Microphone";
              "filter.graph".nodes = [
                {
                  type = "ladspa";
                  name = "rnnoise";
                  plugin = rnnoise;
                  # RNNoise itself is mono. Suppressing a stereo microphone
                  # would run two instances for a voice call that mixes the
                  # result back down anyway.
                  label = "noise_suppressor_mono";
                  control = {
                    "VAD Threshold (%)" = 50.0;
                    "VAD Grace Period (ms)" = 200;
                    "Retroactive VAD Grace (ms)" = 0;
                  };
                }
              ];
              # RNNoise is trained at 48 kHz, so both ends of the graph are
              # pinned to that rate and resampling stays outside the filter.
              "capture.props" = {
                "node.name" = "capture.rnnoise_source";
                # Passive keeps the graph idle until something actually reads
                # the filtered source, so an unused suppressor neither holds
                # the hardware microphone open nor drives itself.
                "node.passive" = true;
                "audio.rate" = 48000;
                "audio.channels" = 1;
                "audio.position" = [ "MONO" ];
              };
              "playback.props" = {
                "node.name" = "rnnoise_source";
                "media.class" = "Audio/Source";
                "audio.rate" = 48000;
                "audio.channels" = 1;
                "audio.position" = [ "MONO" ];
              };
            };
          }
        ];
      };
    };
in
{
  flake.modules.nixos.noise-suppression = module;
}
