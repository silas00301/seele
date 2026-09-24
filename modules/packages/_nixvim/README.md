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
