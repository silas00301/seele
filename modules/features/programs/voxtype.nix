{ ... }:
let
  homeModule = (
    {
      lib,
      pkgs,
      ...
    }:
    let
      package = pkgs.voxtype-vulkan;
      model = pkgs.fetchurl {
        name = "ggml-base.en.bin";
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
        hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
      };
      configFile = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
        engine = "whisper";
        hotkey.enabled = false;
        audio = {
          device = "default";
          sample_rate = 16000;
          max_duration_secs = 60;
        };
        whisper = {
          model = toString model;
          language = "en";
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
          wait_for_modifier_release = true;
        };
        osd.enabled = false;
      };
    in
    {
      home.packages = [ package ];

      xdg.configFile."voxtype/config.toml".source = configFile;

      systemd.user.services.voxtype = {
        Unit = {
          Description = "Voxtype push-to-talk voice-to-text daemon";
          Documentation = "https://voxtype.io";
          PartOf = [ "graphical-session.target" ];
          After = [
            "graphical-session.target"
            "pipewire.service"
            "pipewire-pulse.service"
          ];
        };
        Service = {
          ExecStart = "${package}/bin/voxtype daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind(
          "SUPER + D",
          hl.dsp.exec_cmd("${package}/bin/voxtype record start"),
          { description = "Start Voxtype dictation" }
        )

        hl.bind(
          "SUPER + D",
          hl.dsp.exec_cmd("${package}/bin/voxtype record stop"),
          {
            release = true,
            description = "Stop Voxtype dictation",
          }
        )
      '';
    }
  );
  nixosModule = (
    { username, ... }:
    {
      users.users.${username}.extraGroups = [ "input" ];
    }
  );
in
{
  flake.modules.homeManager.voxtype = homeModule;
  flake.modules.nixos.voxtype = nixosModule;
}
