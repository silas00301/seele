{ ... }:
{
  flake.modules.nixos.backup-browser =
    { config, lib, pkgs, selfPackages, username, ... }:
    let
      cfg = config.seele.backup.browser;
      credential = lib.types.nullOr (lib.types.strMatching "/[^\n]+");
      reference = path: path != null && !(lib.hasPrefix "/nix/store/" path);
      backend = pkgs.runCommand "seele-backup-files" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
        mkdir -p "$out/bin"
        makeWrapper ${selfPackages.maintenance}/bin/seele-backup-files "$out/bin/seele-backup-files" \
          --set SEELE_RESTIC_BIN ${lib.getExe pkgs.restic} \
          --set SEELE_RESTIC_PATH ${lib.makeBinPath [ pkgs.openssh ]} \
          --set SEELE_BACKUP_REPOSITORY_FILE ${lib.escapeShellArg cfg.repositoryFile} \
          --set SEELE_BACKUP_PASSWORD_FILE ${lib.escapeShellArg cfg.passwordFile} \
          --set SEELE_BACKUP_BACKEND_FILE ${lib.escapeShellArg (if cfg.environmentFile == null then "" else cfg.environmentFile)} \
          --set SEELE_BACKUP_ALLOWED_HOME ${lib.escapeShellArg config.users.users.${username}.home} \
          --set SEELE_BACKUP_HOST ${lib.escapeShellArg config.networking.hostName}
      '';
      frontend = pkgs.runCommand "seele-restore-file" { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
        mkdir -p "$out/bin"
        makeWrapper ${selfPackages.maintenance}/bin/seele-restore-file "$out/bin/seele-restore-file" \
          --set SEELE_BACKUP_FILES_HELPER ${backend}/bin/seele-backup-files \
          --set SEELE_SHELLCTL ${selfPackages.seele-shell}/bin/seele-shellctl \
          --prefix PATH : ${lib.makeBinPath [ pkgs.systemd pkgs.zenity pkgs.diffutils ]}
      '';
    in {
      options.seele.backup.browser = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.seele.backup.enable or false;
          description = "Explicit single-file backup preview, comparison and restored-copy workflow.";
        };
        repositoryFile = lib.mkOption {
          type = credential;
          default = config.seele.backup.repositoryFile or null;
          description = "Private repository reference; defaults to the scheduled backup's reference when present.";
        };
        passwordFile = lib.mkOption {
          type = credential;
          default = config.seele.backup.passwordFile or null;
          description = "Private restic password reference, read only by the authenticated root helper.";
        };
        environmentFile = lib.mkOption {
          type = credential;
          default = config.seele.backup.environmentFile or null;
          description = "Optional private backend credentials as strict unquoted KEY=value lines.";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          { assertion = reference cfg.repositoryFile && reference cfg.passwordFile;
            message = "Backup browsing requires private repository and password files outside the Nix store."; }
          { assertion = cfg.environmentFile == null || reference cfg.environmentFile;
            message = "Backup browser backend credentials must stay outside the Nix store."; }
        ];
        environment.systemPackages = [ frontend ];
      };
    };

  flake.modules.homeManager.backup-browser =
    { lib, osConfig ? {}, ... }:
    lib.mkIf (osConfig.seele.backup.browser.enable or false) {
      programs.yazi.keymap.mgr.prepend_keymap = [{
        on = "<A-r>";
        run = "shell ${lib.escapeShellArg ''seele-restore-file "$1"''}";
        desc = "Preview, compare or restore a separate backup copy";
      }];
    };
}
