{ ... }:
let
  # Host entries are machine state: which hosts this machine reaches, as whom,
  # through which jump host and with which key. None of that belongs in a public
  # flake, so the managed file carries only defaults that suit every host and
  # pulls the private entries from a file Home Manager never touches.
  localInclude = "~/.ssh/config.local";

  module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
      sshDirectory = "${config.home.homeDirectory}/.ssh";

      # Control sockets live in a directory only this user can enter, and their
      # names are `%C`, a hash of the local host, remote host, port, user and
      # jump host, so every destination gets its own socket at a fixed length.
      # ssh binds `<path>.<16 random characters>` first and renames it, so the
      # whole path has to fit sun_path (108 bytes on Linux, 104 on macOS) with
      # that suffix attached.
      #
      # On Linux that directory is logind's runtime directory, which is created
      # mode 0700 at login and emptied at logout, so a socket never outlives
      # the session or survives a reboot. It is named through `%i`, the local
      # UID, rather than `${XDG_RUNTIME_DIR}`: OpenSSH aborts every connection
      # whose ControlPath names an unset variable, and environments that drop
      # it (`env -i`, sanitized subprocesses, a `su` without pam_systemd) are
      # exactly the ones in which a failing ssh is hardest to explain.
      # `/run/user/1000/ssh-` plus the hash and suffix is 76 bytes.
      #
      # macOS has no XDG runtime directory, and its per-user `$TMPDIR` below
      # `/var/folders` is long enough that the same name would overflow
      # sun_path, so the sockets go to a private directory below `~/.ssh` that
      # activation creates. A socket left behind by a crash or a reboot is
      # harmless: ssh finds nothing listening, unlinks it and becomes the master.
      controlPath = if isLinux then "/run/user/%i/ssh-%C" else "~/.ssh/control/%C";
    in
    {
      programs.ssh = {
        enable = true;

        # Home Manager's legacy defaults restate OpenSSH's own and will be
        # removed upstream; the explicit block below replaces them.
        enableDefaultConfig = false;

        # Home Manager writes `Include` above every block, and ssh_config takes
        # the first value it obtains for each option. Host entries in the local
        # file therefore win over the managed `Host *` defaults, which only fill
        # in what a local entry leaves unset. A missing file is not an error.
        includes = [ localInclude ];

        settings."*" = {
          # Reuse one authenticated connection for every session to the same
          # destination, and keep it for ten minutes after the last one closes,
          # so repeated `ssh`, `scp` and Git operations skip the handshake and
          # the agent approval. The bound keeps a forgotten master from holding
          # a connection open indefinitely.
          ControlMaster = "auto";
          ControlPath = controlPath;
          ControlPersist = "10m";

          # Notice a dead peer within about a minute and a half instead of
          # waiting for TCP, which matters more with multiplexing: every
          # session sharing a dead master hangs with it.
          ServerAliveInterval = 30;
          ServerAliveCountMax = 3;

          # Record new known hosts as hashes so the file does not list where
          # this account connects, and accept a server's additional or rotated
          # host keys once it has proved the key already trusted.
          HashKnownHosts = true;
          UpdateHostKeys = true;
        };
      };

      # ssh-keygen creates `~/.ssh` mode 0700, while Home Manager's link step
      # would create it with the default umask on a machine that has none yet,
      # so create it first. An existing directory keeps its mode. On macOS this
      # also ensures the control socket directory exists and is private.
      home.activation.sshDirectories = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] (
        ''
          run ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${lib.escapeShellArg sshDirectory}
        ''
        + lib.optionalString (!isLinux) ''
          run ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg "${sshDirectory}/control"}
        ''
      );
    };
in
{
  flake.modules.homeManager.ssh = module;
}
