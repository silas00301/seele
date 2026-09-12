{ ... }:
{
  flake.modules.homeManager.seele-transfers =
    {
      config,
      pkgs,
      selfPackages,
      ...
    }:
    let
      package = selfPackages.seele-shell;
    in
    {
      systemd.user.services.seele-transfers = {
        Unit = {
          Description = "Personal file transfers";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${package}/bin/seele-transfers serve";
          Environment = [ "SEELE_TRANSFERS_DOWNLOADS=${config.xdg.userDirs.download}" ];
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 2;
          NoNewPrivileges = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      xdg.desktopEntries.seele-transfers = {
        name = "Send with Seele Transfers";
        genericName = "Personal file transfer";
        exec = "${package}/bin/seele-transfers select %F";
        icon = "folder-download";
        terminal = false;
        categories = [
          "Network"
          "FileTransfer"
        ];
        mimeType = [ "application/octet-stream" ];
      };
      # KDE-compatible file managers expose one action for all selected files.
      xdg.dataFile."kio/servicemenus/seele-transfers.desktop".text = ''
        [Desktop Entry]
        Type=Service
        MimeType=all/allfiles;
        Actions=send;
        X-KDE-Priority=TopLevel

        [Desktop Action send]
        Name=Send with Seele Transfers
        Icon=folder-download
        Exec=${package}/bin/seele-transfers select %F
      '';
      # Nautilus "Scripts" preserves the file manager's selected path arguments.
      xdg.dataFile."nautilus/scripts/Send with Seele Transfers" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          exec ${package}/bin/seele-transfers select "$@"
        '';
      };
    };
}
