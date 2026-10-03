# Neovim helpers

## Automatic formatting

Press **Space c f** to toggle automatic formatting for the editor session. The
statusline shows **format off** while the active buffer is affected; otherwise
it stays quiet. Toggling does not change text. `:FormatDisable FILETYPE` and
`:FormatEnable FILETYPE` keep the plugin’s native per-filetype controls, and
`:FormatEnable!` resets all disabled states. These settings are session-local.

Validate the mapping and status with the real lsp-format plugin:

```sh
NVIM=/path/to/nvim LSP_FORMAT_DIR=/path/to/lsp-format.nvim python3 modules/packages/_nixvim/test-format-control.py
```

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

The headers show saved decoding and intended output encodings, BOM state,
line-ending format and final-newline state, since native line diffs hide these
metadata-only changes. Unicode BOMs identify saved UTF-8/16 bytes independently
of the buffer's intended output encoding; without a BOM, decoding uses the
buffer's selected encoding (or Neovim's internal encoding when unset). UTF-32
is explicitly unsupported because the native converter is unsafe on some Neovim
builds. The helper rejects unnamed/special buffers, binary text, non-regular or unreadable saved files, and
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

## Search and replace

`<leader>sr` opens grug-far on the current file and `<leader>sR` on the working
directory, following the lowercase-buffer, uppercase-workspace split of the
`sd`/`sD` and `ss`/`sS` searches. Normal mode seeds the search with the word under
the cursor; Visual mode seeds a `--fixed-strings` search with the selection, and a
multi-line selection adds `--multiline`. Every match is previewed before grug-far's
own replace action writes anything. Unnamed and special buffers, and filenames
containing control characters, are refused with a warning instead of widening the
scope to the whole directory. Spaces in the file scope are escaped the way
grug-far's paths input expects.

Run the real fixture with Neovim, ripgrep and a grug-far.nvim checkout:

```sh
GRUG_FAR=/path/to/grug-far.nvim python3 modules/packages/_nixvim/test-replace.py
```

It replaces in a temporary project and checks the result on disk: the file scope
leaves another file's match untouched, the directory scope reaches both, a
charwise selection becomes a literal search, and non-file buffers open nothing.

## Persistent undo

`undo.vim` manages private undo state and excludes sensitive/runtime paths.
`test-undo.py` exercises real editor writes and reloads; see its header for the
writable-directory requirement and Vim fallback.

## Completion confirmation

Completion suggestions start unselected. Tab and Shift-Tab select a candidate;
Enter accepts only that explicit selection. With an unselected or closed popup,
Enter keeps its normal action instead of swallowing a newline or accepting the
first suggestion. The same confirmation policy covers Insert, Select and command
modes.

Run the isolated real-plugin fixture with Neovim and nvim-cmp available:

```sh
NVIM=/path/to/nvim CMP_DIR=/path/to/nvim-cmp python3 modules/packages/_nixvim/test-completion.py
```
