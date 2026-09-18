{ ... }:
let
  module = {
    # NixOS already starts systemd-oomd: `systemd.oomd.enable` defaults to
    # true. Every slice option next to it defaults to false, so out of the box
    # the daemon runs with nothing under management and kills nothing. This
    # picks the one cgroup it should watch here and leaves the other two off
    # on purpose. No earlyoom beside it: it decides on free memory and free
    # swap, and the 16 GiB of zram this machine carries is designed to fill,
    # so it would sit at its trigger during a healthy build -- and it picks
    # single processes by RSS, with no idea which one holds the display up.
    systemd.oomd = {
      # The children of system.slice are ordinary daemons, and the only one
      # that grows without bound here is nix-daemon.service: `max-jobs = 2`
      # with `cores = 6` regularly puts two builds and a dozen compilers in
      # that single cgroup. Losing it costs a rebuild, which `seele-rebuild`
      # already reports; losing the session costs everything that was open.
      enableSystemSlice = true;

      # Monitoring `-.slice` makes system.slice and user.slice the candidates,
      # so its idea of relieving pressure is killing every daemon, or the
      # whole login session, in one move.
      enableRootSlice = false;

      # This one is off for a reason specific to this desktop. Hyprland runs
      # as `wayland-wm@Hyprland.service` in session.slice, and everything it
      # launches with `exec` -- browser, IDE, terminals -- stays inside that
      # one cgroup. Monitoring user slices would therefore give oomd a single
      # worthwhile candidate inside the session, and killing it takes the
      # compositor, Seele Shell and every open window with it. Per-application
      # candidates would first need applications started through `uwsm app`.
      enableUserSlices = false;
    };

    systemd.slices."system".sliceConfig = {
      # ManagedOOMSwap stays unset everywhere: zram at `vm.swappiness = 100`
      # is meant to be full, so swap usage carries no signal here and oomd's
      # SwapUsedLimit would fire on a perfectly healthy build. Pressure is the
      # honest measure -- the share of a 10 second window in which every task
      # in system.slice was stalled waiting for memory.
      ManagedOOMMemoryPressureLimit = "60%";
      # Against oomd's 30 second default, which is a very long time to look at
      # a compositor that cannot paint.
      ManagedOOMMemoryPressureDurationSec = "15s";
    };

    # oomd ranks candidates by reclaim activity, so a thrashing build already
    # outranks an idle daemon. These two own the way back to a usable screen:
    # logind owns the session, greetd owns the greeter and the login path a
    # lock screen falls back to.
    systemd.services.systemd-logind.serviceConfig.ManagedOOMPreference = "avoid";
    systemd.services.greetd.serviceConfig.ManagedOOMPreference = "avoid";

    systemd.services.nix-daemon.serviceConfig = {
      # The kernel scales oom_score_adj by total memory, so on 32 GiB every
      # 100 points is worth 3.2 GiB of apparent size. This makes builds look
      # 16 GiB larger than they are, which is enough for the kernel's own OOM
      # killer to reach past every window for them, and nix-daemon.socket
      # brings the daemon back on the next connection.
      OOMScoreAdjust = 500;
      # Deliberately MemoryHigh and not MemoryMax: crossing it throttles the
      # build into reclaim rather than failing it with an opaque kill. Half of
      # RAM for at most two concurrent jobs means a runaway link step gives up
      # its own page cache to zram instead of evicting the desktop's.
      MemoryHigh = "16G";
    };

    # Only the system manager may lower oom_score_adj; a user manager has no
    # CAP_SYS_RESOURCE, so a negative value on a user unit is silently dropped
    # and the session has to be discounted from here and inherited. 250 points
    # is 8 GiB of head start over system.slice. Inside the session the kernel
    # still chooses by size, which already means a browser long before a
    # compositor or a shell of a few hundred megabytes.
    systemd.services."user@".serviceConfig.OOMScoreAdjust = -250;
  };
in
{
  flake.modules.nixos.nerv-memory-pressure = module;
  flake.modules.nixos.nerv-system = module;
  flake.modules.nixos.nerv = module;
}
