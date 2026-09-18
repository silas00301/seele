{ ... }:
let
  # Thirty days is what GNOME's `org.gnome.desktop.privacy.old-files-age`
  # defaults to, and it is the useful shape of the window: a deletion that was
  # a mistake is noticed within a day or two, while the one that is noticed
  # weeks later is noticed because something else went looking for the file.
  # Past a month the trash stops being an undo buffer and becomes a second copy
  # of everything, which is the failure mode that makes people empty it by
  # reflex and lose the habit.
  retentionDays = 30;

  module =
    {
      config,
      pkgs,
      ...
    }:
    {
      # trash-cli is the FreeDesktop trashcan on the command line. Yazi already
      # writes the same trash -- its `d` goes through the Rust `trash` crate,
      # which resolves `$XDG_DATA_HOME/Trash` exactly as trash-cli does -- so
      # this is the missing CLI half of a trash that already exists rather than
      # a second one beside it, and `trash-list`/`trash-restore` see what the
      # file manager deleted too.
      home.packages = [ pkgs.trash-cli ];

      # `rm` is deliberately left alone.
      #
      # Shadowing it with `trash-put` would make the safety net exist only where
      # it is least needed. A Fish abbreviation or alias covers the interactive
      # prompt on this machine and nothing else: a script, a non-interactive
      # ssh command, and anything under `run0` all reach the real `rm`, so the
      # habit it trains is wrong precisely when the command runs as root or on
      # a machine that is not this one. The flag surfaces do not line up either
      # -- `trash-put` has no `-r`, no `-f` and no `--one-file-system`, so
      # `rm -rf build` under a shadowed `rm` either errors or silently means
      # something else -- and unlearning a shadowed `rm` costs a real deletion.
      #
      # So the safe path is made the short one instead. `tp` is fewer keystrokes
      # than `rm`, which is the only argument that ever decides this.
      #
      # `tr` is coreutils' translate and is not taken, however well it would
      # have read. `trash-empty` gets no abbreviation at all: it is the one
      # irreversible command here, the timer below already does its routine
      # work, and typing it out in full is the gate.
      programs.fish.shellAbbrs = {
        tp = {
          position = "command";
          expansion = "trash-put";
        };
        tl = {
          position = "command";
          expansion = "trash-list";
        };
        tre = {
          position = "command";
          expansion = "trash-restore";
        };
      };

      systemd.user.services.trash-empty = {
        Unit.Description = "Expire trashed files older than ${toString retentionDays} days";
        Service = {
          Type = "oneshot";
          # The positional day count is what makes this an expiry rather than an
          # empty: trash-cli deletes only the entries whose `.trashinfo`
          # deletion date is older than it, and leaves the rest. `-f` is the
          # documented opposite of `-i`. trash-empty defaults `--interactive` to
          # `isatty(0)`, so a unit with no stdin is already non-interactive and
          # this only makes the unit unable to acquire a prompt later.
          ExecStart = "${pkgs.trash-cli}/bin/trash-empty -f ${toString retentionDays}";
          # trash-cli locates the home trash from `XDG_DATA_HOME`, falling back
          # to `HOME/.local/share`. The user manager does not necessarily carry
          # the graphical session's value, and a timer that prunes a different
          # directory than the shell fills is worse than no timer, so it is
          # named here from the same option the rest of this configuration uses.
          Environment = [ "XDG_DATA_HOME=${config.xdg.dataHome}" ];
          # Unlinking a month of trash can be a lot of small IO. Nothing waits
          # on it, so let it lose every race with the desktop.
          Nice = 19;
          IOSchedulingClass = "idle";
        };
      };

      systemd.user.timers.trash-empty = {
        Unit.Description = "Daily expiry of trashed files";
        Timer = {
          OnCalendar = "daily";
          # A workstation is off or asleep at the hour a daily timer names, so
          # without this the trash would only ever be pruned on a machine that
          # happened to be awake at midnight -- which is to say never.
          Persistent = true;
          # Persistent means the catch-up run lands during login. An hour of
          # jitter keeps it off that path.
          RandomizedDelaySec = "1h";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
in
{
  # Linux only, and not for want of a package: `trash-cli` is
  # `lib.platforms.unix` in the pinned nixpkgs and would build on `asuka`. It
  # implements the FreeDesktop spec, so on macOS it would fill
  # `~/.local/share/Trash` -- a directory Finder does not show, does not restore
  # from, and does not clear when it empties the Trash. macOS already has the
  # recoverable deletion this feature is for, under Cmd-Delete and Put Back;
  # adding an invisible second trash next to it would reproduce the command
  # rather than the intent.
  flake.modules.homeManager.trash = module;
}
