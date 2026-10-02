# Neovim helpers

## Compare unsaved text with the saved file

Press **Space c s** (`<leader>cs`) or run `:SavedDiff`. A dedicated tab shows the
saved file on the left and a snapshot of the current buffer on the right. Both
panes are read-only. The original buffer stays in its original window, with its
edits, undo history, folds, view and any existing diff session intact.

Press **q** or **Escape** in either pane, use `:SavedDiffClose`, or invoke
`:SavedDiff` again to close the comparison and return. Ordinary `:q`, `:tabclose`
and deleting either snapshot clean up its partner too. Only one comparison is
open at a time; close and reopen it to take fresh snapshots, including external
changes to the saved file. The comparison never saves a file or changes cwd.

The headers show line-ending format and whether the final newline is present,
since native line diffs do not highlight final-newline differences. Saved bytes
are decoded using the original buffer's file encoding. The helper rejects
unnamed/special buffers, binary text, non-regular or unreadable saved files, and
either side larger than 2 MiB or 20,000 lines. Scratch content has no swap or
persistent undo, never runs modelines or file-reading/FileType hooks, and is
wiped on close.

Run the real-buffer fixture with an existing Neovim (no plugins required):

```sh
NVIM=/path/to/nvim python3 modules/packages/_nixvim/test-saved-diff.py
```

It creates and removes its own temporary HOME/state/files. It covers source
preservation, diff isolation, repeated invocation and window/buffer cleanup,
read-only snapshots, external changes, line endings, modeline-looking text,
unusual filenames, FIFO and error paths. Run as an ordinary user so the
unreadable-file fixture can exercise permission denial.

## Show where a line came from

Press **Space b** (`<leader>b`) or run `:LineOrigin` to see which change last
touched the cursor line: its short id, author, relative and absolute date and
full description, in a small popup below the line. In Visual mode, or with an Ex
range such as `:12,18LineOrigin`, the popup holds one section per distinct
change, in the order the lines appear, each naming its lines. The popup takes
the keyboard; the footer lists its actions, which apply to the section under the
cursor:

- **y** copies the id to the unnamed register and the clipboard provider: the
  full Jujutsu change id, which survives rewrites, or the Git commit hash.
- **Enter** or **d** opens the change's diff (`jj show --git` or `git show`) in a
  read-only scratch tab, at this file's part of it; **q** closes it.
- **p** steps to the version of that line before the change: it annotates the
  change's parent and shows what the line replaced, or the line it was inserted
  after. Press it again to keep walking back.
- **q** or **Escape** closes the popup and returns to the source window.

Short ids are drawn as Jujutsu draws them, unique prefix first and the rest
dimmed. Highlights link to standard groups (`Special`, `Identifier`, `Comment`,
`Title`, `DiagnosticHint`, `DiagnosticWarn`, `FloatBorder`) and are restored on
every `ColorScheme`, so they follow the theme switcher's presets.

In a Jujutsu repository, colocated or not, the helper runs `jj file annotate`;
in a plain Git repository it runs `git blame --porcelain`. The nearest `.jj` or
`.git` marker above the file decides, preferring Jujutsu at a colocated root,
and a colocated repository falls back to Git when `jj` is not installed. Both
commands come from the user's `PATH`, so they match the repository's own tools.
Outside a repository, for a file that was never saved, or one the VCS does not
track, the helper says so instead of opening a popup.

Annotating never records anything. jj runs with `--ignore-working-copy`: without
it, any jj command snapshots the working copy, which writes a new working-copy
commit and operation, can start tracking new files, and in a colocated repository
also imports Git's `HEAD` and refs. A read-only question should not create history,
and should not race another jj process that is rewriting the repository.
Instead the helper reads the saved file and maps it onto jj's last recorded
working copy with `vim.diff`: a saved line jj has not recorded yet is attributed
to the working-copy change, as jj itself will do at its next snapshot, and the
section says so. Git annotates the saved bytes directly through
`--contents -`, with optional locks off so it never refreshes the index. Lines
edited in the buffer since the last save are mapped the same way and shown as
**Not saved yet**, never attributed to a change; Git's saved but uncommitted
lines read **Not committed yet**. A buffer that is unmodified but differs from
the disk is refused, since its text is older than the save rather than newer.

Every command is an argv list run with `vim.system`, never through a shell or a
blocking `system()`. Each one has `--no-pager` and forces colour off (`--color
never`, `-c color.ui=never`); Git also disables signature display and external
diff drivers and leaves non-ASCII paths unquoted, and jj's diff skips signature verification. Output is
bounded (8 MiB for annotations, 1 MiB for metadata, 4 MiB for a diff, which is
truncated with a note) and each command times out after 15 seconds. A result is
discarded when the buffer changed while it ran or a newer request or popup action
has started. Files and buffers over 2 MiB or 20,000 lines are refused, and a
range spanning more than 50 changes shows the first 50. Metadata text is shown
as text with control characters removed.

Run the real-repository fixture with Neovim, `jj` and `git` on `PATH` (or
`NVIM=/path/to/nvim`):

```sh
python3 modules/packages/_nixvim/test-line-origin.py
```

It builds throwaway colocated and native Jujutsu repositories and a Git
repository with fixed authors and dates and a hostile pager/colour/signature
configuration. It drives the real normal and visual mappings and checks exact
popup text, range grouping, unsaved and unrecorded lines, parent stepping, copy
and diff actions, stale-result handling, highlight restoration, refusals and the
exact argv of every command. It then verifies that the jj operation log, both
`.git` directories and the saved file are unchanged.

## Copy source reference

`<leader>cp` copies the current buffer's project-relative `path:line`; in Visual
mode it copies the selected line span as `path:start-end`. `<leader>cP` uses an
absolute path. `:CopyReference` and `:CopyReference!` provide the same actions,
including explicit Ex ranges such as `:12,18CopyReference`. Visual selections
stay selected. A one-line selection produces just one line number.

Project discovery reads ancestor markers from the file's directory, independently
of the editor's current directory: the nearest `.jj` directory or `.git` directory
or file is the root. This includes Git worktrees and nested projects, with Jujutsu
preferred at a shared root. It does not invoke either VCS, validate the repository,
snapshot a working copy, or write repository data. Outside a marked project the
reference uses the absolute filename. Paths follow Neovim's buffer name, retaining
its symlink spelling where Neovim has not already reused an existing buffer.
Named new files are supported. Unnamed buffers, special buffers, non-file paths,
and names containing colons or control characters are refused because they cannot
be represented unambiguously in this format.

The explicit result replaces characterwise register `r` (`"rp` to paste) and is
sent to the existing `+` clipboard provider when available. The message distinguishes
an unavailable or throwing provider from a submitted copy. Asynchronous providers
such as OSC 52 cannot acknowledge the terminal's eventual clipboard write, so the
message does not claim confirmed delivery. Register `r` remains usable if clipboard
delivery fails. Other editor registers, contents, cursor, view, undo history and
selection are preserved, except an unnamed register already pointing at `r` or `+`
necessarily reflects that destination's update. No file contents are copied.

Run the real Neovim fixture without loading personal configuration:

```sh
python3 modules/packages/_nixvim/test-copy-reference.py
```

It uses temporary directories and a private clipboard callback, exercises normal
and visual mappings, range semantics, project boundaries and hostile filenames,
checks provider failure/fallback, and verifies unchanged repository data and editor
state. A real desktop/terminal clipboard still needs validation in that session.

## Persistent undo

`undo.vim` manages private undo state and excludes sensitive/runtime paths.
`test-undo.py` exercises real editor writes and reloads; see its header for the
writable-directory requirement and Vim fallback.
