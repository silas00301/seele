{ ... }:
let
  # A build or test run that outlasts the attention it was started with should
  # say when it is over. The `done` plugin times every interactive command and,
  # when one runs past the threshold and finishes while its terminal window is
  # not the focused one, raises a desktop notification with its duration,
  # directory and exit status. Nothing is sent over SSH, for a command that
  # finished in front of the user, or for the plugin's `git` exclusions.
  module =
    { pkgs, ... }:
    {
      programs.fish = {
        plugins = [
          {
            name = "done";
            inherit (pkgs.fishPlugins.done) src;
          }
        ];
        # The plugin reads these when each command ends, so config.fish can set
        # them after its conf.d snippet has installed the defaults.
        interactiveShellInit = ''
          set -g __done_min_cmd_duration 10000
        '';
      };
    };

  # On nerv the notification goes to Seele Shell with a Show action that brings
  # the command back: the Ghostty window it was typed in regains focus through
  # the shell's validated window endpoint, and inside tmux its pane is selected
  # again. The plugin's own notify-send path marks the message transient with a
  # three-second expiry, and the shell never lists a transient notification in
  # its panel and withdraws it once the toast retires, so someone who looked
  # away would never see it; it also raises failures as critical, which the
  # shell keeps on screen until dismissed. This one is an ordinary
  # notification with the shell's own lifetime; the title already says whether
  # the command failed.
  seeleModule =
    {
      config,
      lib,
      pkgs,
      selfPackages,
      ...
    }:
    let
      notify = pkgs.writeShellScript "seele-command-done" ''
        set -u
        exec </dev/null >/dev/null 2>&1
        title=$1 message=$2 window=$3 pane=$4

        # notify-send stays connected until the notification is acted on or
        # closed, since only that connection can receive the action; bound it
        # so a notification nobody reads does not keep a process forever.
        action="$(${pkgs.coreutils}/bin/timeout 1h ${pkgs.libnotify}/bin/notify-send \
          --app-name=Ghostty \
          --icon=com.mitchellh.ghostty \
          --action=default=Show \
          -- "$title" "$message")" || exit 0
        [ "$action" = default ] || exit 0

        # `hyprctl activewindow` reports the address without its prefix.
        if [ -n "$window" ]; then
          case $window in
            0x*) ;;
            *) window="0x$window" ;;
          esac
          ${selfPackages.seele-shell}/bin/seele-control vicinae-focus window "$window"
        fi
        # The inherited TMUX names the server; selecting the window and pane
        # changes that session's view without switching any other client.
        if [ -n "$pane" ]; then
          ${lib.getExe config.programs.tmux.package} select-window -t "$pane" \
            && ${lib.getExe config.programs.tmux.package} select-pane -t "$pane"
        fi
      '';
    in
    {
      # fish evaluates the command where `title`, `message` and the window id
      # are local, and expands them as single arguments without re-parsing
      # them, so the command line in the message is never executed.
      programs.fish.interactiveShellInit = ''
        set -g __done_notification_command '${notify} "$title" "$message" "$__done_initial_window_id" "$TMUX_PANE" &; disown'
      '';
    };
in
{
  flake.modules.homeManager = {
    command-notifications = module;
    command-notifications-seele = seeleModule;
  };
}
