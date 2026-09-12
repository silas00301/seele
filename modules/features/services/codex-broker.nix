{ ... }:
{
  flake.modules.homeManager.codex-broker =
    {
      config,
      lib,
      options,
      selfPackages,
      ...
    }:
    let
      cfg = config.seele.codexBroker;
      package = selfPackages.codex-broker;
    in
    {
      options.seele.codexBroker = {
        model = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9_.:-]+";
          default = "gpt-5.6-luna";
          description = "Broker-owned model used for integration inference.";
        };
        concurrency = lib.mkOption {
          type = lib.types.ints.between 1 8;
          default = 2;
        };
        idleSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 300;
        };
      };
      config = lib.mkMerge [
        {
          home.packages = [ package ];
          systemd.user.sockets.seele-codex = {
            Unit.Description = "Private Seele Codex inference socket";
            Socket = {
              ListenStream = "%t/seele-codex.sock";
              SocketMode = "0600";
              RemoveOnStop = true;
            };
            Install.WantedBy = [ "sockets.target" ];
          };
          systemd.user.services.seele-codex = {
            Unit.Description = "Seele Codex inference broker";
            Service = {
              ExecStart = "${lib.getExe package} serve --model ${lib.escapeShellArg cfg.model} --concurrency ${toString cfg.concurrency} --idle ${toString cfg.idleSeconds}";
              Restart = "on-failure";
              RestartSec = 1;
              UMask = "0077";
              NoNewPrivileges = true;
              LimitCORE = 0;
            };
          };
        }
        (lib.optionalAttrs (lib.hasAttrByPath [ "seele" "health" "providers" ] options) {
          seele.health.providers.codex = {
            enable = true;
            name = "Codex broker";
            deadline = 90000;
            service = "seele-codex.service";
            actions = [
              "restart"
              "diagnostics"
            ];
            disruptive = [ "restart" ];
          };
          systemd.user.services.seele-codex-health = {
            Unit = {
              Description = "Publish Codex broker health";
              After = [ "seele-shell.service" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${package}/bin/seele-codex-health";
              Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
              TimeoutStartSec = 25;
              UMask = "0077";
            };
          };
          systemd.user.timers.seele-codex-health = {
            Unit.PartOf = [ "graphical-session.target" ];
            Timer = {
              OnActiveSec = "1s";
              OnUnitActiveSec = "30s";
              AccuracySec = "1s";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        })
      ];
    };
}
