{ ... }:
let
  # Nothing on this machine reads what its drives already know. SMART keeps the
  # manufacturer's own health verdict, the error log, and the reallocated and
  # pending sector counters, and those move long before a read actually fails.
  # smartd polls them on a schedule and says so while the disk is still
  # readable. Backups are the answer to a disk that has died; this is the
  # warning that arrives early enough to make one.
  module =
    { lib, pkgs, ... }:
    let
      # The two arguments smartd's own notify script broadcasts on a warning.
      # Sending them by hand exercises the same delivery path with no failing
      # hardware involved.
      testNotification = lib.concatStringsSep " " [
        "${pkgs.dbus}/bin/dbus-send"
        "--system"
        "/"
        "net.nuetzlich.SystemNotifications.Notify"
        ''"string:Problem detected with disk: /dev/seele-health-test"''
        ''"string:Warning message from smartd is: Seele disk health delivery test"''
      ];

      # smartmontools installs its commands into `sbin`, and NixOS puts only
      # `/bin` of the system profile on `PATH`, so installing the package
      # alone would leave `smartctl` unreachable by name. Link whichever
      # directory the package actually ships, and fail the build rather than
      # install a dangling command if that layout ever changes.
      smartctl = pkgs.runCommand "seele-smartctl" { } ''
        mkdir -p "$out/bin"
        for directory in sbin bin; do
          candidate="${pkgs.smartmontools}/$directory/smartctl"
          if [ -x "$candidate" ]; then
            ln -sf "$candidate" "$out/bin/smartctl"
          fi
        done
        [ -e "$out/bin/smartctl" ]
      '';
    in
    {
      services.smartd = {
        enable = true;

        # Monitor whatever is attached instead of naming devices. Every
        # filesystem here is referenced by UUID precisely so a disk can be
        # replaced without editing the configuration, and a device list would
        # quietly stop covering the replacement.
        autodetect = true;

        # `-a` is upstream's default and already covers the health verdict,
        # both logs, and the sector counters. `-s` adds the one thing polling
        # cannot: a short self-test nightly at 02:00 and a long one Saturday at
        # 03:00, which is what exercises a failing region no ordinary read has
        # reached yet. A drive without self-test support logs that it declined
        # and stays monitored by everything else.
        defaults.autodetected = "-a -s (S/../.././02|L/../../6/03)";

        notifications = {
          # Seele Shell owns `org.freedesktop.Notifications`, and a root
          # service cannot address the session bus it listens on.
          # systembus-notify is the bridge: smartd broadcasts on the system
          # bus, and the per-user daemon -- which the upstream module enables
          # along with this option -- forwards it into the running session, so
          # the warning lands in the same notification UI as everything else.
          # It also lets any local user post notifications; this machine has
          # one account.
          systembus-notify.enable = true;

          # Upstream decides whether to pass `-M exec` to smartd from the
          # mail, wall, and X11 toggles alone; the systembus-notify one is not
          # part of that condition. Wall's default is what currently keeps the
          # notify script attached, so state the dependency here rather than
          # leaving a later cleanup of "unused" terminal notifications to
          # silently remove every desktop warning with it.
          wall.enable = true;

          # This host enables `services.xserver` for its keymap, which is what
          # upstream reads to decide on X11 notifications. The session is
          # Hyprland, so nothing would ever display that xmessage, and leaving
          # it on only adds it to the system closure.
          x11.enable = false;
        };
      };

      # Reading the same data by hand is the other half of owning it:
      # `smartctl -a /dev/nvme0` for the full report, `smartctl -t long
      # /dev/nvme0` for a test outside the schedule. smartd itself runs from
      # its own store path and needs nothing here.
      environment.systemPackages = [ smartctl ];

      # Deliberately dormant, the way `seele-failure-test` is:
      # `systemctl start seele-disk-health-test` sends exactly the message
      # smartd sends, so the path from a root service to a desktop
      # notification can be verified on the live machine without waiting for
      # hardware to fail -- and re-verified after either end of it changes.
      systemd.services.seele-disk-health-test = {
        description = "Send a test disk health notification";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = testNotification;
        };
      };

      # smartd failing is itself a disk-health event, and it needs no wiring
      # here: the failure-analysis generator attaches its `OnFailure=` reporter
      # to installed system services, so a monitor that stops monitoring
      # reports itself through the same private path as any other unit.
    };
in
{
  flake.modules.nixos.disk-health = module;
}
