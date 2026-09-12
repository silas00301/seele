{ ... }:
{
  flake.modules.homeManager.maintenance =
    {
      config,
      lib,
      options,
      pkgs,
      selfPackages,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.seele.maintenance;
      package = selfPackages.maintenance;
      json = pkgs.writeText "seele-maintenance.json" (builtins.toJSON cfg);
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      interval =
        seconds:
        mkOption {
          type = types.ints.positive;
          default = seconds;
        };
      identity = mkOption { type = types.strMatching "[A-Za-z0-9_.:@/-]+"; };
      label = mkOption { type = types.str; };
      path = mkOption { type = types.str; };
      scope = mkOption {
        type = types.enum [
          "user"
          "system"
        ];
        default = "user";
      };
      flakePath = "${config.home.homeDirectory}/Developer/seele";
    in
    {
      options.seele.maintenance = {
        intervalSeconds = interval 60;
        systemd = {
          enabled = enabled;
          scope = mkOption {
            type = types.enum [
              "user"
              "system"
            ];
            default = "system";
          };
        };
        disk = {
          enabled = enabled;
          paths = mkOption {
            type = types.listOf types.str;
            default = [ "/" ];
          };
          soonPercent = mkOption {
            type = types.ints.between 1 99;
            default = 85;
          };
          nowPercent = mkOption {
            type = types.ints.between 2 100;
            default = 95;
          };
        };
        backups = {
          enabled = enabled;
          items = mkOption {
            default = [ ];
            type = types.listOf (
              types.submodule {
                options = {
                  id = identity;
                  inherit label scope;
                  unit = mkOption { type = types.strMatching "[A-Za-z0-9_.:@-]+\\.service"; };
                  maxAgeHours = mkOption {
                    type = types.ints.positive;
                    default = 24;
                  };
                  successFile = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Backup-owned file touched only after success; enables age checks across reboots.";
                  };
                };
              }
            );
          };
        };
        flake = {
          enabled = enabled;
          path = mkOption {
            type = types.str;
            default = flakePath;
          };
          intervalSeconds = interval 86400;
        };
        certificates = {
          enabled = enabled;
          items = mkOption {
            default = [ ];
            type = types.listOf (
              types.submodule {
                options = {
                  id = identity;
                  inherit label path;
                  soonDays = mkOption {
                    type = types.ints.positive;
                    default = 30;
                  };
                  nowDays = mkOption {
                    type = types.ints.unsigned;
                    default = 7;
                  };
                };
              }
            );
          };
        };
        inputs = {
          enabled = enabled;
          path = mkOption {
            type = types.str;
            default = flakePath;
          };
          intervalSeconds = interval 86400;
          items = mkOption {
            default = [
              {
                id = "nixpkgs";
                maxAgeDays = 30;
              }
            ];
            type = types.listOf (
              types.submodule {
                options = {
                  id = identity;
                  maxAgeDays = mkOption {
                    type = types.ints.positive;
                    default = 30;
                  };
                };
              }
            );
          };
        };
      };
      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = cfg.disk.soonPercent < cfg.disk.nowPercent;
              message = "Maintenance disk warning threshold must precede critical threshold.";
            }
            {
              assertion = builtins.all (item: item.nowDays < item.soonDays) cfg.certificates.items;
              message = "Maintenance certificate warning threshold must precede critical threshold.";
            }
            {
              assertion =
                builtins.all
                  (items: builtins.length (lib.unique (map (item: item.id) items)) == builtins.length items)
                  [
                    cfg.backups.items
                    cfg.certificates.items
                    cfg.inputs.items
                  ];
              message = "Maintenance publisher IDs must be unique within each source.";
            }
          ];
          home.packages = [ package ];
          systemd.user.sockets.seele-maintenance = {
            Unit.Description = "Private Seele maintenance socket";
            Socket = {
              ListenStream = "%t/seele-maintenance.sock";
              SocketMode = "0600";
              RemoveOnStop = true;
            };
            Install.WantedBy = [ "sockets.target" ];
          };
          systemd.user.services.seele-maintenance = {
            Unit = {
              Description = "Seele maintenance findings";
              Requires = [ "seele-maintenance.socket" ];
              After = [ "seele-maintenance.socket" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${lib.getExe package} serve --config ${json}";
              Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
              Restart = "on-failure";
              RestartSec = 2;
              UMask = "0077";
              NoNewPrivileges = true;
              LimitCORE = 0;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        }
        (lib.optionalAttrs (lib.hasAttrByPath [ "seele" "health" "providers" ] options) {
          seele.health.providers.backups = {
            enable = cfg.backups.enabled && cfg.backups.items != [ ];
            name = "Backups";
            deadline = lib.min 3600000 (lib.max 90000 (cfg.intervalSeconds * 3000));
            actions = [ "diagnostics" ];
          };
        })
      ];
    };
}
