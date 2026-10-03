# tmux helpers

## Move a running pane

Mark a pane with **Ctrl+s, m**, navigate to the destination pane, then press
**Ctrl+s, j** to bring it below the destination or **Ctrl+s, J** to bring it
alongside on the right. The source may be in another window or session on the
same tmux server. This moves the existing terminal and its running job; nothing
is restarted. Native **Ctrl+s, !** breaks a pane back into its own window.

The mark uses tmux's native border indicator. **Ctrl+s, M** clears it. tmux
may clear a mark as its originating window disappears; mark the pane again
before another move. An empty source window disappears, and taking the last
window out of a session removes that session, following native tmux behavior.
Choosing the marked pane itself reports tmux's ordinary error without moving it.
Without a mark, both keys explain how to mark a source and leave every pane alone.
The existing Ctrl+h/j/k/l editor/pane navigation is unaffected.

The bindings are native tmux commands in `pane-move.conf`, shared by managed
and portable tmux. Run their private-server fixture with an installed tmux:

```sh
python3 modules/features/programs/_tmux/test-pane-move.py
```

`checks.<system>.tmux-pane-move` packages the same test. It uses its own socket,
temporary HOME and attached PTY, exercises actual keys for both layouts, missing
marks, same-window/cross-session moves and self-joins, and checks pane process IDs
stay unchanged. It never contacts the live server.

## Pane scrollback viewer

**Ctrl+s, r** reloads the configuration file that installed the binding, including
a portable or custom XDG configuration. The path is captured during loading and
quoted for tmux’s native file expansion, so spaces and glob characters stay
literal. Included plugin files do not replace it. Errors remain visible instead
of being followed by an unconditional success message.

Validate with `python3 modules/features/programs/_tmux/test-reload.py`.

Press **Ctrl+s, H** in tmux to browse the originating pane's screen and up to
10,000 retained history rows in a temporary Neovim popup. Use `/` and `?` to
search, `n`/`N` to move between matches, `v`, `V`, or Ctrl+v to select, and `y`
to copy and close. `yy` copies a whole line. `q` or Escape in normal mode closes
without copying; Escape in visual mode cancels the selection.

Managed and portable tmux retain up to 10,000 history rows per pane, matching
the viewer’s capture window. The limit applies when a pane is created: after
reloading the configuration, open a new pane or window to get the larger history.
Existing panes keep their old limit, and discarded output cannot be recovered.

Soft terminal wraps join back into logical lines; hard line breaks remain.
Neovim wraps those logical lines to the popup width. Linewise copies include a
final newline, characterwise and rectangular copies do not add one. Capture
strips terminal styling, includes the normal pane grid that tmux exposes, and
does not recover history tmux has already discarded. Captures over 8 MiB fail
with a message; tmux's own prefix+y copy mode remains available.

The launcher records the originating socket, pane ID and client using tmux's
shell-quoting formatter, then passes them as separate arguments/environment
values. Opening and dismissing never changes tmux's paste buffers. An explicit
yank loads a tmux buffer and sends the selection to that client's terminal
clipboard through `load-buffer -w`, including over SSH; terminal clipboard
permissions still apply. It never pastes into the original pane.

The scratch buffer has no user configuration or plugins, modelines, swap,
persistent undo, ShaDa, backups or editor logs. Captured text stays in memory.
The Home Manager tmux feature pins an unconfigured Neovim directly in its
launcher, so its portable output carries the same viewer without needing the
full configured editor feature. No background service is added.

Run the private-server fixture with installed tmux and Neovim (0.10 or newer):

```sh
python3 modules/features/programs/_tmux/test-scrollback.py
# Or override either executable:
NVIM_BIN=/path/to/nvim TMUX_BIN=/path/to/tmux python3 modules/features/programs/_tmux/test-scrollback.py
```

It uses synthetic history, an isolated HOME, its own socket and an attached PTY;
it never contacts the live tmux server. It checks pane identity, history and byte
bounds, wrap and newline handling, search, scratch privacy, cancel, linewise and
characterwise copy, terminal OSC 52, missing-pane failure and the actual popup
binding. `checks.<system>.tmux-scrollback` packages this same fixture.

## Failed panes

A pane whose command exits unsuccessfully keeps its scrollback and shows the
exit status or signal with the recovery keys. **Ctrl+s, Shift+R** restarts that
pane's original command; it never restarts a running pane. **Ctrl+s, q** closes
it. **Ctrl+s, H** opens the existing scrollback search, and **Ctrl+s, y** enters
copy mode. Successful command exits close their panes normally.

This observes the process running the pane, not a command inside an interactive
shell: a failed command that returns to the Fish prompt does not retain a pane
or change the prompt. Deliberately exiting Fish with a nonzero status does retain
its pane; use the close key to dismiss it. Restart repeats the original command
and its original working directory, so choose it deliberately for commands with
side effects. Nothing automatically retries a failed command.

The policy is in `failed-panes.conf`, read directly by the managed and portable
tmux configurations. The `tmux-failed-panes` flake check exercises real private
servers, attached keyboard bindings, successful and failed task/Fish exits,
signal termination, preserved history, restart, dismissal and running-pane
refusal. Run it with existing binaries:

```sh
python3 modules/features/programs/_tmux/test-failed-panes.py modules/features/programs/_tmux/failed-panes.conf tmux fish
```

The fixture was validated with the flake's tmux 3.7c and Fish 4.9.3 versions,
with tmux built standalone and Fish from its verified official release.
The older system tmux 3.4 intermittently retained fast successful panes with no
exit status or signal; it does not establish the packaged behavior. The fixture
keeps fast commands in its coverage and does not delay them to mask that failure.


## Broadcast input to a window's panes

Press **Ctrl+s, Shift+s** to toggle tmux's native pane synchronization for the
current window. While enabled, the status bar shows **BROADCAST** in reverse bold
text and typed input reaches every eligible pane in that window. Press the same
keys again to stop; the bar label disappears. Other windows keep their own state,
so switching away hides the label and returning to a synchronized window restores
it. Synchronization starts off and is not persisted across servers.

Run `python3 modules/features/programs/_tmux/test-broadcast.py` to exercise the
actual binding through an attached private PTY, verify input duplication and
window isolation, and check the live status label. The existing
`checks.<system>.tmux-scrollback` also runs this fixture.
