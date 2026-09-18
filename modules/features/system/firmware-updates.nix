{ ... }:
let
  # Every other layer of this machine is updated by rebuilding the flake, and
  # firmware is the one that is not. The storage controllers, the Logitech
  # receiver, an eventual dock and the mainboard each carry a version that no
  # generation touches, and the vendors publish the fixes -- including security
  # fixes -- to LVFS. fwupd already downloads that metadata daily once it is
  # enabled; what it does with the result is write a message of the day that a
  # Hyprland session never shows anyone. So enable the daemon, and hand its
  # verdict to the notification server this desktop already reads.
  #
  # Finding an update and installing one stay separate. Firmware is the least
  # reversible thing on the machine, so nothing here installs anything: the
  # notification names the devices and leaves `fwupdmgr update` to a deliberate
  # decision.
  module =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      runtimeDirectory = "seele-firmware-check";
      check =
        pkgs.runCommand "seele-firmware-check"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          }
          ''
            mkdir -p "$out/bin"
            makeWrapper "${selfPackages.desktop-tools}/bin/seele-firmware-check" "$out/bin/seele-firmware-check" \
              --prefix PATH : "${
                lib.makeBinPath [
                  config.services.fwupd.package
                  pkgs.dbus
                ]
              }"
          '';
    in
    {
      services.fwupd = {
        enable = true;

        # Passim shares downloaded files with the local network so that other
        # machines refresh from a neighbour instead of LVFS. Upstream documents
        # that it intends to make that the default; this host is the only one
        # of its kind on any network it joins, so the sharing would be pure
        # exposure. Pin the current behaviour rather than inherit that change.
        daemonSettings.P2pPolicy = "nothing";
      };

      # Seele Shell owns `org.freedesktop.Notifications`, and a root service
      # cannot address the session bus it listens on. systembus-notify is the
      # bridge: the check broadcasts on the system bus and the per-user daemon
      # forwards it into the running session. It also lets any local user post
      # notifications; this machine has one account.
      services.systembus-notify.enable = true;

      # Ten minutes after boot, then daily. Boot is when a staged capsule has
      # just been applied and when somebody is actually in front of the
      # machine, so it is the run most likely to be seen; the daily one only
      # catches a session that stays up for weeks.
      systemd.timers.seele-firmware-check = {
        description = "Check for available firmware updates";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10min";
          OnUnitActiveSec = "1d";
        };
      };

      # fwupd's own packaged timer refreshes the LVFS metadata. This reads only
      # what that refresh left behind, so it needs no network of its own, and
      # it is ordered after it merely to avoid reading a half-written cache.
      systemd.services.seele-firmware-check = {
        description = "Report available firmware updates";
        after = [ "fwupd-refresh.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${check}/bin/seele-firmware-check";
          RuntimeDirectory = runtimeDirectory;
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = "yes";
          PrivateTmp = true;
          UMask = "0077";
          NoNewPrivileges = true;
          LimitCORE = 0;
        };
      };

      # Deliberately dormant, the way `seele-failure-test` is:
      # `systemctl start seele-firmware-test` sends exactly the message the
      # check sends, so the path from a root service to a desktop notification
      # can be verified on the live machine without waiting for a vendor to
      # publish something -- and re-verified after either end of it changes.
      systemd.services.seele-firmware-test = {
        description = "Send a test firmware update notification";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${check}/bin/seele-firmware-check --test";
        };
      };

      # `fwupdmgr get-devices` lists what is enumerated and `fwupdmgr update`
      # installs, both from the package the fwupd module already installs. The
      # UEFI capsule path is the exception worth knowing about: this host boots
      # Limine with its own Secure Boot keys, so a capsule staged through
      # fwupd's own EFI binary is not signed by anything this firmware trusts.
      # Peripheral and storage firmware is unaffected; treat a mainboard offer
      # as a separate decision rather than a routine update.
    };
in
{
  flake.modules.nixos.firmware-updates = module;
}
