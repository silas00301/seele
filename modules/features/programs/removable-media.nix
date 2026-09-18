{ ... }:
let
  # Plugging a USB stick into this machine does nothing. udisks2 is already in
  # the closure, because Plasma 6 sits there as a fallback session and depends
  # on it, but nothing in the Hyprland session is listening, so the disk waits
  # until somebody mounts it by hand. Name the service here rather than
  # inheriting it from a session the machine does not normally start: the
  # capability belongs to the desktop that is actually running.
  #
  # udisks2 mounts a removable device for the user who owns the active local
  # session without asking polkit for a password, and puts it below
  # `/run/media/$USER`. Nothing here needs to widen that.
  systemModule = {
    services.udisks2.enable = true;

    # The disks that arrive from elsewhere are the ones formatted elsewhere:
    # exFAT for anything that has to survive a camera or a phone, NTFS for
    # anything that came off a Windows machine. Without the drivers, udisks
    # reads the filesystem, reports it, and then declines to mount it, which
    # looks like the automounter being broken rather than the kernel missing a
    # module.
    boot.supportedFilesystems = {
      exfat = true;
      ntfs = true;
    };
  };

  homeModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # `--all` is narrower than it reads: udiskie only ever considers the
      # devices it would have mounted itself, which are the external ones, so
      # this cannot reach into the root filesystem or a permanent internal
      # disk. `--detach` is the part that matters -- unmounting alone leaves
      # the drive powered and still caching, and the point of pressing a key
      # instead of pulling the stick is to be told when it is genuinely safe.
      #
      # The daemon raises its own notice for every device it lets go, so the
      # only thing left for the key to report is the case the daemon never
      # sees: a still-open file keeping the unmount from happening at all.
      # That one has to be loud, because the alternative is the user believing
      # the eject worked.
      eject = pkgs.writeShellScript "seele-eject" ''
        set -uo pipefail

        if error="$(${pkgs.udiskie}/bin/udiskie-umount --all --detach 2>&1)"; then
          exit 0
        fi

        ${pkgs.libnotify}/bin/notify-send \
          --app-name=udiskie \
          --icon=media-eject \
          --urgency=critical \
          "Removable media is still in use" \
          "''${error:-Could not unmount every removable device.}"
        exit 1
      '';
    in
    {
      services.udiskie = {
        enable = true;

        # Both are udiskie's defaults. Say them anyway: automounting and being
        # told about it are the entire feature, and a silent default is a poor
        # place to keep a requirement.
        automount = true;
        notify = true;

        # Seele Shell owns the bar and the notification server, and its tray
        # already holds the applications that live there permanently. A GTK
        # icon that appears only while a stick is plugged in would be a second
        # place to look for something the notification has already said, so the
        # per-device menu it would carry is traded for one key below.
        tray = "never";

        settings.program_options = {
          # udiskie offers a Browse action on the mount notification, and
          # Seele's notification server is one of the few that actually runs
          # the actions it is handed. Point it at the file manager this
          # configuration already uses instead of udiskie's `xdg-open`
          # default, which would hand a directory to whichever desktop opener
          # happens to answer.
          file_manager = "${pkgs.ghostty}/bin/ghostty -e ${config.programs.yazi.package}/bin/yazi";
        };
      };

      # Eject is one of the few desktop actions with a wrong way to do it that
      # is always available, so the right way has to be quicker than reaching
      # for the stick. SHIFT because it acts on every attached device at once.
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("${eject}"), { description = "Safely eject removable media" })
      '';
    };
in
{
  flake.modules.nixos.removable-media = systemModule;
  flake.modules.homeManager.removable-media = homeModule;
}
