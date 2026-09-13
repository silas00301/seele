{ ... }:
let
  mkFailureAnalysis =
    {
      lib,
      nhPackage,
      pkgs,
      selfPackages,
    }:
    pkgs.runCommand "seele-failure-analysis" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
      mkdir -p "$out/bin" "$out/lib/systemd/system-generators"
      install -Dm644 ${./_failure-analysis/view.lua} \
        "$out/share/seele-failure-analysis/view.lua"

      for binary in seele-failure-report seele-rebuild; do
        makeWrapper "${selfPackages.failure-analysis}/bin/$binary" "$out/bin/$binary" \
          --set SEELE_FAILURE_SELF "$out/bin/seele-failure-report" \
          --set SEELE_FAILURE_ENV "${pkgs.coreutils}/bin/env" \
          --set SEELE_FAILURE_GHOSTTY "${pkgs.ghostty}/bin/ghostty" \
          --set SEELE_FAILURE_JOURNALCTL "${pkgs.systemd}/bin/journalctl" \
          --set SEELE_FAILURE_NH "${lib.getExe nhPackage}" \
          --set SEELE_FAILURE_NOTIFY "${pkgs.libnotify}/bin/notify-send" \
          --set SEELE_FAILURE_NVIM "${selfPackages.nixvim}/bin/nvim" \
          --set SEELE_FAILURE_RUNUSER "${pkgs.util-linux}/bin/runuser" \
          --set SEELE_FAILURE_SYSTEMCTL "${pkgs.systemd}/bin/systemctl" \
          --set SEELE_FAILURE_SYSTEMD_RUN "${pkgs.systemd}/bin/systemd-run" \
          --set SEELE_FAILURE_VIEW_LUA "$out/share/seele-failure-analysis/view.lua"
      done
      ln -s ${selfPackages.failure-analysis}/bin/seele-failure-generator \
        "$out/lib/systemd/system-generators/seele-failure-analysis"
    '';

  homeModule =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      package = mkFailureAnalysis {
        inherit lib pkgs selfPackages;
        nhPackage = config.programs.nh.package;
      };
    in
    {
      home.packages = [ package ];

      programs.fish.shellAbbrs.rebuild = lib.mkForce {
        position = "command";
        expansion = "${package}/bin/seele-rebuild";
      };

      # The OS session already delegates rebuilding through SEELE_SHELL_NH.
      # Replacing that executable preserves its flow while making its failure
      # enter the same private, opt-in analysis path as ordinary failed units.
      systemd.user.services.seele-shell.Service.Environment = lib.mkAfter [
        "SEELE_SHELL_NH=${package}/bin/seele-rebuild"
      ];

      # Local reports open as a short-lived, centered scratch buffer. The
      # notification itself stays in Seele Shell's native notification UI.
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.window_rule({
          match = {
            class = [[^org\.seele\.failure$]],
          },
          float = true,
          size = { 960, 640 },
          move = {
            "monitor_w*0.5-window_w*0.5",
            "monitor_h*0.5-window_h*0.5",
          },
        })
      '';
    };

  nixosModule =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      username,
      ...
    }:
    let
      userHome = config.home-manager.users.${username};
      package = mkFailureAnalysis {
        inherit lib pkgs selfPackages;
        nhPackage = userHome.programs.nh.package;
      };
    in
    {
      environment.systemPackages = [ package ];

      systemd.generators.seele-failure-analysis = "${package}/lib/systemd/system-generators/seele-failure-analysis";

      systemd.services."seele-failure-report@" = {
        description = "Offer a private report for failed unit %I";
        after = [ "systemd-journald.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${package}/bin/seele-failure-report collect-unit %I ${username}";
          PrivateTmp = true;
          TimeoutStartSec = "11min";
          UMask = "0077";
          NoNewPrivileges = true;
          LimitCORE = 0;
        };
      };

      # Deliberately dormant: `systemctl start seele-failure-test` exercises
      # collection, consent, local viewing, and optional analysis end to end.
      systemd.services.seele-failure-test = {
        description = "Deliberately fail to test Seele failure analysis";
        unitConfig.OnFailure = "seele-failure-report@%n.service";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/false";
        };
      };
    };
in
{
  flake.modules.homeManager.failure-analysis = homeModule;
  flake.modules.nixos.failure-analysis = nixosModule;
}
