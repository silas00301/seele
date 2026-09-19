{ ... }:
let
  homeModule = (
    {
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      package = selfPackages.voxtype;
      # FP32 TDT v3 batch export. Japanese is unsupported; streaming is SIL-66.
      modelRevision = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";
      modelHashes = {
        "encoder-model.onnx" = "sha256-mKdLIbTMABfB5wMDGaSpb0qVBuUPBwjzpRbQKnfJa7E=";
        "encoder-model.onnx.data" = "sha256-miLTcsUUVcNPE0BdolILrvtxJb0WmBOXVhQj7TLSTzY=";
        "decoder_joint-model.onnx" = "sha256-6Xjd9miFJxgsEP3i60uDBoQhZImF7yP3qGvnMr6HBsE=";
        "vocab.txt" = "sha256-1YVEZ56kvGrFY9H1Ret9R0vWz6Rn8KbiwdwcfTfjw10=";
      };
      modelFiles = lib.mapAttrs (
        name: hash:
        pkgs.fetchurl {
          inherit name hash;
          url = "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/${modelRevision}/${name}";
        }
      ) modelHashes;
      model = pkgs.runCommand "parakeet-tdt-0.6b-v3-fp32-${builtins.substring 0 8 modelRevision}" { } ''
        mkdir -p "$out"
        ${lib.concatMapStringsSep "\n" (name: ''
          cp ${modelFiles.${name}} "$out/${name}"
        '') (builtins.attrNames modelFiles)}
      '';
      configFile = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
        engine = "parakeet";
        # Hyprland owns the toggle binding; do not grant raw input access.
        hotkey.enabled = false;
        audio = {
          device = "default";
          sample_rate = 16000;
          max_duration_secs = 60;
        };
        parakeet = {
          model = toString model;
          model_type = "tdt";
          streaming = false;
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
          Description = "Voxtype batch Parakeet voice-to-text daemon";
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
          UMask = "0077";
          LimitCORE = 0;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind(
          "SUPER + D",
          hl.dsp.exec_cmd("${package}/bin/voxtype record toggle"),
          { description = "Toggle Voxtype dictation" }
        )
      '';
    }
  );
in
{
  flake.modules.homeManager.voxtype = homeModule;
}
