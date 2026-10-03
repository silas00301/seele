{ ... }:
let
  module =
    {
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      package = selfPackages.seele-shell;

      # logind reads the power key itself and, with `HandlePowerKey=` at its
      # default, powers off the moment it is pressed, so a bumped case ends the
      # session and whatever was unsaved in it. GNOME and KDE both take it back
      # the same way: while the desktop runs, it holds logind's
      # `handle-power-key` inhibitor and shows its own end-session choice. The
      # compositor sees the key regardless, because logind reads the device
      # without grabbing it.
      #
      # An inhibitor rather than `HandlePowerKey=ignore` in logind.conf: the
      # lock lasts exactly as long as this session, so the greeter and a bare
      # TTY keep a key that works, and a session that could not take the lock
      # keeps the clean poweroff it had before instead of a key that does
      # nothing. The fallback Plasma session starts this unit as well, where
      # PowerDevil answers the key with its own dialog and the second lock
      # changes nothing. `block` because a `delay` inhibitor only
      # postpones the action it names. The same inhibitor also covers the long
      # press; logind reports both through `INHIBIT_HANDLE_POWER_KEY`.
      inhibit = lib.escapeShellArgs [
        "${pkgs.systemd}/bin/systemd-inhibit"
        "--what=handle-power-key"
        "--mode=block"
        "--who=Seele Shell"
        "--why=The power key opens the Power panel"
        "${pkgs.coreutils}/bin/sleep"
        "infinity"
      ];
    in
    {
      # Polkit grants this lock only to a process in a local session, and a
      # user service belongs to none; polkit answers for it with the user's
      # display session instead, which is what lets this run under the user
      # manager beside Caffeinate. The descriptor dies with the process, so
      # logging out, a crash or a stopped graphical session all hand the key
      # back to logind at once.
      systemd.user.services.seele-power-key = {
        Unit = {
          Description = "Hand the power key to Seele Shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # A refusal from polkit is an answer for the whole session, so three
          # attempts are enough to ride out a transient bus failure without
          # retrying a denial into the journal every two seconds.
          StartLimitIntervalSec = 60;
          StartLimitBurst = 3;
        };
        Service = {
          ExecStart = inhibit;
          Restart = "on-failure";
          RestartSec = 2;
          NoNewPrivileges = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        -- The Power panel is the same choice Super + Escape offers, and the
        -- same key toggles it away again. The bind is not `locked`, so a locked
        -- session ignores the key: the shell's panels draw beneath the lock
        -- surface, where opening one would show nothing, and the lock screen
        -- carries its own confirmed Power grid for the same choice. The
        -- firmware's hold-to-off override does not pass through logind and
        -- still works.
        hl.bind(
          "XF86PowerOff",
          hl.dsp.exec_cmd("${package}/bin/seele-shellctl controls"),
          { description = "Open the Power panel" }
        )
      '';
    };
in
{
  flake.modules.homeManager.power-key = module;
}
