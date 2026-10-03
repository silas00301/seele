{ ... }:
{
  flake.modules.homeManager.hermes =
    { config, lib, pkgs, selfPackages, ... }:
    let
      cfg = config.seele.hermes;
      desktop = selfPackages.hermes-desktop;
      shell = selfPackages.seele-shell;
    in
    {
      options.seele.hermes = {
        enable = lib.mkEnableOption "Hermes Desktop and approved nerv tools";
        gatewayUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://hermes:9119";
          description = "Non-secret remote Desktop gateway URL on the tailnet. Credentials belong in Desktop's system-wallet-backed connection settings.";
        };
        peer = lib.mkOption {
          type = lib.types.str;
          default = "hermes";
          description = "Exact Tailscale node DNS name (or its first label) allowed to call MCP. Use the full tailnet name to disambiguate peers.";
        };
        port = lib.mkOption { type = lib.types.port; default = 8766; };
        flake = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/Developer/seele";
          description = "Fixed local Seele checkout used by metadata queries and explicitly approved rebuilds.";
        };
        services = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "nix-daemon.service" ];
          description = "Explicit system service allowlist for status and redacted logs. Journal permissions are not elevated.";
        };
        allowRebuild = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow Hermes to request a rebuild; each request still requires local approval and system authentication.";
        };
      };
      config = lib.mkIf cfg.enable {
        home.packages = [ desktop ];
        xdg.configFile."seele-shell/hermes.json".text = builtins.toJSON { enable = true; };
        seele.health.providers.hermes = {
          enable = true;
          name = "Hermes";
          deadline = 15000;
          setup = "hermes";
          service = "seele-hermes.service";
          actions = [ "settings" "restart" ];
          disruptive = [ "restart" ];
        };
        # All GUI entry points get the default URL, without overriding saved
        # connections or placing credentials in an environment or Nix store.
        home.sessionVariables.SEELE_HERMES_GATEWAY = cfg.gatewayUrl;
        systemd.user.services.seele-hermes = {
          Unit = {
            Description = "Hermes Desktop lifecycle and approved nerv MCP tools";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
            StartLimitIntervalSec = 0;
          };
          Service = {
            ExecStart = "${shell}/bin/seele-hermes serve";
            Environment = [
              "PATH=${lib.makeBinPath [ desktop shell pkgs.ghostty pkgs.jujutsu pkgs.nvd pkgs.systemd pkgs.tailscale ]}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
              "SEELE_HERMES_GATEWAY=${cfg.gatewayUrl}"
              "SEELE_HERMES_PEER=${cfg.peer}"
              "SEELE_HERMES_PORT=${toString cfg.port}"
              "SEELE_HERMES_FLAKE=${cfg.flake}"
              "SEELE_HERMES_SERVICES=${lib.concatStringsSep "," cfg.services}"
              "SEELE_HERMES_ALLOW_REBUILD=${if cfg.allowRebuild then "1" else "0"}"
            ];
            UMask = "0077";
            RuntimeDirectory = "seele-hermes";
            RuntimeDirectoryMode = "0700";
            Restart = "on-failure";
            RestartSec = 5;
            NoNewPrivileges = true;
            LimitCORE = 0;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  flake.modules.nixos.hermes =
    { config, username, lib, ... }:
    let cfg = config.home-manager.users.${username}.seele.hermes;
    in {
      # Bound to the Tailscale address and authenticated by tailscaled per
      # request; no public TCP opening or incoming SSH mode is added.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.mkIf cfg.enable [ cfg.port ];
    };
}
