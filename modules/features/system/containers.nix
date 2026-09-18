{ ... }:
let
  # A throwaway Postgres, a CI image, an upstream project's compose file. All
  # of it runs as the desktop user in that user's own namespace: no daemon, no
  # group membership that grants root-equivalent access, and no privileged
  # socket. Option paths and defaults below were read at the pinned nixpkgs
  # revision in `nixos/modules/virtualisation/podman/default.nix`.
  nixosModule =
    { lib, pkgs, ... }:
    {
      virtualisation.podman = {
        enable = true;

        # `podman compose` is a thin wrapper that execs an external provider
        # resolved with exec.LookPath; podman 5.8.6 vendors a default provider
        # list ending in "docker-compose" and "podman-compose". Placing Compose
        # v2 in podman's own wrapper PATH rather than in the user's profile
        # keeps upstream compose files working without putting a Docker-named
        # command on the interactive shell. Enabling the module already
        # rebuilds podman through the `package` option's `apply`, so naming
        # `extraPackages` costs no additional build.
        extraPackages = [ pkgs.docker-compose ];

        # `dockerCompat` stays at its default of false. It adds a package whose
        # only content is a `docker` symlink to podman, and that command then
        # answers for a tool this machine does not have: a script that assumes
        # Docker semantics gets podman's rootless view instead, and a later real
        # Docker install collides with a system package rather than replacing
        # it. Interoperability is kept where it can still say which engine
        # answered — the compose provider above, and the per-user API socket
        # below, which speaks the Docker API on a socket named podman.

        # `dockerSocket.enable` stays false for a harder reason. Its own option
        # description upstream reads: "Users must be in the `podman` group in
        # order to connect. As with Docker, members of this group can gain root
        # access." Rootless podman exists precisely to avoid that group, so
        # /run/docker.sock is not offered here.

        # `autoPrune` stays off. The unit it enables, systemd.services
        # .podman-prune, runs `podman system prune -f` as root and therefore
        # only ever reaches the rootful store under /var/lib/containers/storage,
        # which nothing on this host writes to. Disk-pressure hygiene for the
        # store that does fill up belongs to the user session; see the Home
        # Manager module below. Nix generation retention stays with `nh clean`
        # and is untouched by either.

        # `defaultNetwork.settings` is deliberately left empty. Setting
        # `dns_enabled` there writes /etc/containers/networks/podman.json, and
        # netavark only reads that directory as root: podman resolves the
        # rootless network configuration directory to "$graphroot/networks"
        # instead. The same setting is also what makes the upstream module open
        # UDP 53 on podman0 in the host firewall, so spelling it out would punch
        # a hole for a rootful path this host never takes while changing nothing
        # for the rootless one. Container-to-container name resolution comes
        # from aardvark-dns, which ships inside the podman package's helper
        # directory, on the user-defined networks that `podman network create`
        # and compose projects make for themselves.
      };

      # The upstream module enables the rootful API socket unconditionally
      # (`systemd.sockets.podman.wantedBy = [ "sockets.target" ]`, socket group
      # "podman"). The `podman` group has no members on this host and nothing
      # here wants a root-owned container API listening, so the socket unit is
      # not installed into sockets.target at all — the same treatment
      # `nerv/ssh.nix` gives sshd. The per-user socket
      # (`systemd.user.sockets.podman`) stays enabled: it lives in
      # $XDG_RUNTIME_DIR, is owned by the user, and is what `podman compose`
      # points DOCKER_HOST at.
      systemd.sockets.podman.wantedBy = lib.mkForce [ ];

      # Subordinate UID/GID ranges are intentionally not configured.
      # `nixos/modules/config/users-groups.nix` defaults `autoSubUidGidRange` to
      # true for every user with `isNormalUser`, and update-users-groups.pl
      # allocates a 65536-wide range from 100000 upward and records it in
      # /var/lib/nixos/auto-subuid-map so it is stable across rebuilds. Writing
      # `subUidRanges` by hand would replace that allocation, and the script
      # warns that changed subordinate ids require re-owning every file a
      # rootless container already created.
    };

  # Container storage is the user's, so pruning is the user's too. A root timer
  # cannot see ~/.local/share/containers/storage, and a system-wide user unit
  # would also start for the greeter.
  homeModule =
    { pkgs, ... }:
    let
      # The podman the system installed, not a second copy of it. A prune has
      # to use the same wrapper, storage configuration and helper binaries as
      # the interactive CLI; referring to `pkgs.podman` here would fork a
      # separate store path whose view of the store could drift from it.
      podman = "/run/current-system/sw/bin/podman";
    in
    {
      home.packages = [ pkgs.podman-tui ];

      programs.fish.shellAbbrs = {
        pod = {
          position = "command";
          expansion = "podman";
        };
        pods = {
          position = "command";
          expansion = "podman ps --all";
        };
        podc = {
          position = "command";
          expansion = "podman compose";
        };
      };

      # Bounded and non-destructive by construction. No `--all`, so a tagged
      # image the user pulled on purpose survives being momentarily unused and
      # only dangling layers and build cache go. No volume flag, because
      # removing a volume is data loss and that decision stays with an explicit
      # `podman volume prune`. `until=168h` keeps the sweep off anything touched
      # in the last week, so a container stopped this morning is still there
      # tonight; a running workload is never a prune candidate in the first
      # place.
      systemd.user.services.seele-podman-prune = {
        Unit.Description = "Prune unused rootless Podman data";
        Service = {
          Type = "oneshot";
          ExecStart = "${podman} system prune --force --filter until=168h";
        };
      };

      systemd.user.timers.seele-podman-prune = {
        Unit.Description = "Weekly rootless Podman prune";
        Timer = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
in
{
  flake.modules.nixos.podman = nixosModule;
  flake.modules.homeManager.podman = homeModule;
}
