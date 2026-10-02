# Pane scrollback viewer

Press **Ctrl+s, H** in tmux to browse the originating pane's screen and up to
10,000 retained history rows in a temporary Neovim popup. Use `/` and `?` to
search, `n`/`N` to move between matches, `v`, `V`, or Ctrl+v to select, and `y`
to copy and close. `yy` copies a whole line. `q` or Escape in normal mode closes
without copying; Escape in visual mode cancels the selection.

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

