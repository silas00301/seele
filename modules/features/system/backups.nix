{ ... }:
{
  flake.modules.nixos.backups =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      username,
      ...
    }:
    let
      cfg = config.seele.backup;
      absolute = lib.types.strMatching "/[^\n]+";
      credential = lib.types.nullOr absolute;
      state = "/var/lib/seele-backup";
      helper = "${selfPackages.maintenance}/bin/seele-restic-test";
      restoreConfig = pkgs.writeText "seele-restic-test.json" (builtins.toJSON {
        restic = lib.getExe pkgs.restic;
        host = config.networking.hostName;
        samples = cfg.restoreSamples;
        runtime = "/run/seele-backup-restore";
        receipt = "${state}/restore-receipt.json";
      });
      reference = path: path != null && !(lib.hasPrefix "/nix/store/" path);
      environment = {
        RESTIC_REPOSITORY_FILE = cfg.repositoryFile;
        RESTIC_PASSWORD_FILE = cfg.passwordFile;
        RESTIC_CACHE_DIR = "/var/cache/restic-backups-seele";
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        SEELE_BACKUP_ENVIRONMENT_FILE = cfg.environmentFile;
      };
      notify = pkgs.writeShellScript "seele-backup-failed" ''
        exec ${pkgs.dbus}/bin/dbus-send --system / \
          net.nuetzlich.SystemNotifications.Notify \
          'string:Seele backup needs attention' \
          'string:A backup or restore check failed. Open System Health to inspect and retry it.'
      '';
    in
    {
      options.seele.backup = {
        enable = lib.mkEnableOption "scheduled encrypted backups and real restore checks";
        repositoryFile = lib.mkOption {
          type = credential;
          default = null;
          description = "Private runtime file naming an already initialized restic repository; never a store path.";
        };
        passwordFile = lib.mkOption {
          type = credential;
          default = null;
          description = "Private runtime restic password file; its contents never enter Nix.";
        };
        environmentFile = lib.mkOption {
          type = credential;
          default = null;
          description = "Optional private systemd environment file for backend credentials.";
        };
        paths = lib.mkOption {
          type = lib.types.listOf absolute;
          default = [ ];
          description = "Explicit durable-data path list, independent of any root persistence migration.";
        };
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        restoreSamples = lib.mkOption {
          type = lib.types.listOf absolute;
          default = [ ];
          description = "One to sixteen real regular files, each at most 16 MiB, restored and compared monthly.";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = reference cfg.repositoryFile && reference cfg.passwordFile;
            message = "Seele backups require private runtime repository and password file references.";
          }
          {
            assertion = cfg.environmentFile == null || reference cfg.environmentFile;
            message = "Seele backup backend credentials must stay outside the Nix store.";
          }
          {
            assertion = cfg.paths != [ ] && cfg.restoreSamples != [ ] && builtins.length cfg.restoreSamples <= 16;
            message = "Seele backups require explicit paths and one to sixteen real restore sample files.";
          }
          {
            assertion = builtins.all (sample: builtins.any (path: sample == path || lib.hasPrefix "${path}/" sample) cfg.paths) cfg.restoreSamples;
            message = "Every Seele restore sample must be included in the backup path list.";
          }
        ];
        services.systembus-notify.enable = true;
        services.restic.backups.seele = {
          inherit (cfg) repositoryFile passwordFile environmentFile paths exclude;
          initialize = false;
          createWrapper = false;
          extraBackupArgs = [ "--tag seele" ];
          timerConfig = {
            OnCalendar = "*-*-* 02:30:00";
            Persistent = true;
            RandomizedDelaySec = "30min";
          };
          # Preserve snapshots. Retention is a separate deliberate policy.
          pruneOpts = [ ];
        };
        systemd.services.restic-backups-seele = {
          unitConfig.OnFailure = [ "seele-backup-failed.service" ];
          environment = lib.optionalAttrs (cfg.environmentFile != null) {
            SEELE_BACKUP_ENVIRONMENT_FILE = cfg.environmentFile;
          };
          preStart = lib.mkBefore ''
            ${helper} --validate-credentials
          '';
          serviceConfig = {
            StateDirectory = "seele-backup";
            StateDirectoryMode = "0755";
            ExecStartPost = "${pkgs.coreutils}/bin/touch ${state}/backup-success";
            UMask = "0077";
            LimitCORE = 0;
          };
        };
        systemd.services.seele-backup-restore = {
          description = "Restore and compare selected real backup files";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" "restic-backups-seele.service" ];
          unitConfig.OnFailure = [ "seele-backup-failed.service" ];
          inherit environment;
          path = [ pkgs.openssh ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${helper} ${restoreConfig}";
            ExecStartPost = "${pkgs.coreutils}/bin/touch ${state}/restore-success";
            StateDirectory = "seele-backup";
            StateDirectoryMode = "0755";
            RuntimeDirectory = "seele-backup-restore";
            RuntimeDirectoryMode = "0700";
            CacheDirectory = "restic-backups-seele";
            CacheDirectoryMode = "0700";
            UMask = "0077";
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            LimitCORE = 0;
            TimeoutStartSec = "6h";
          } // lib.optionalAttrs (cfg.environmentFile != null) {
            EnvironmentFile = cfg.environmentFile;
          };
        };
        systemd.timers.seele-backup-restore = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "monthly";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
        systemd.services.seele-backup-failed = {
          description = "Report a failed backup or restore check";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = notify;
          };
        };
        home-manager.users.${username}.seele.maintenance.backups = {
          enabled = true;
          items = [
            {
              id = "restic-seele";
              label = "Encrypted backup";
              scope = "system";
              unit = "restic-backups-seele.service";
              maxAgeHours = 36;
              successFile = "${state}/backup-success";
            }
            {
              id = "restic-seele-restore";
              label = "Backup restore check";
              scope = "system";
              unit = "seele-backup-restore.service";
              maxAgeHours = 35 * 24;
              successFile = "${state}/restore-success";
            }
          ];
        };
      };
    };
}
