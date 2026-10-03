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

## Trim trailing whitespace

`<leader>cw` trims trailing ASCII spaces and tabs from the buffer. In Visual
mode it trims the complete selected lines (including character/block selections).
`:TrimWhitespace` does the same for the whole buffer, or accepts an explicit
range such as `:12,18TrimWhitespace`. It never saves or runs automatically.
Leading indentation, nonbreaking spaces, search and yank registers, unchanged
text marks, and the window view stay intact; one undo restores the cleanup.
If the cursor was inside removed whitespace, Neovim clamps it to the new line end.
Read-only, unmodifiable and special buffers are refused, even with `!`.

For Markdown and MDX filetypes, nonblank lines ending in at least two spaces
are preserved because those spaces can encode hard line breaks. This deliberately
conservative rule also preserves such lines inside code fences; it is not a
Markdown parser. The result reports preserved lines. `:TrimWhitespace!` removes
those suffixes too, and accepts the same ranges. Other filetypes trim all trailing
ASCII spaces/tabs. Cleanup is explicit because whitespace can carry meaning in
other formats too.

The `nixvim-whitespace` flake check runs the isolated real-editor fixture. With
an existing Neovim it can also run directly:

```sh
NVIM=/path/to/nvim python3 modules/packages/_nixvim/test-trim-whitespace.py
```

It covers normal and visual mappings, line ranges, one-step undo/redo, unchanged
registers and extmarks, no-op undo preservation, Unicode, Markdown, refusal paths,
and the absence of writes to the source file.

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

## Text search

Lowercase `/` and `?` searches match either case. An uppercase letter in the
pattern makes the search case-sensitive. Explicit `\C` and `\c` pattern flags
still force sensitive and insensitive matching respectively.

## Persistent undo

`undo.vim` manages private undo state and excludes sensitive/runtime paths.
`test-undo.py` exercises real editor writes and reloads; see its header for the
writable-directory requirement and Vim fallback.

## Spell checking

Commit messages, Jujutsu descriptions, Markdown, plain text and mail open with
`spell` on; every other filetype, source code included, stays unchecked.
Treesitter queries and syntax files decide what counts as prose inside those
buffers, so code spans, URLs, wikilinks, a `type(scope):` prefix, change IDs and
the generated file lists are not flagged. Use Neovim's own `]s`/`[s`, `z=` and
`zg`; `:setlocal spell` turns it on anywhere else.

`spelllang` is `en_us,de_de`. English comes from Neovim's runtime.
`german-spell.nix` builds `de.utf-8.spl` and its suggestion file with `:mkspell`
from the frami word lists adapted for Vim, the source Vim's own published German
file is built from, including the Austrian and Swiss lists as regions. A
spelling that is only right across a border is therefore marked regional rather
than wrong, and Neovim never offers to download a spell file. The build checks
that both files exist, because `:mkspell` can abandon a word list and still exit
successfully.

nvim-treesitter's `jjdescription` query marks only hand-written `JJ:` comments
as spellable. With a Treesitter highlighter active, Neovim checks nothing else,
so `jjdescription-spell.scm` extends it to the subject and body.

`zg` writes to `stdpath('data')/spell/personal.utf-8.add`. The directory is
created with mode `0700`, because Neovim does not create it and the list can
hold people's names. The store-built runtime path is never written.

Run the real Neovim fixture with a built German spell directory and
nvim-treesitter's `jjdescription` parser and base highlights query:

```sh
NVIM=/path/to/nvim python3 modules/packages/_nixvim/test-spell.py \
  SPELL_DIR PARSER.so highlights.scm
```

It isolates every XDG directory and walks each buffer with `]s`/`]S`, so syntax
and Treesitter decide the result exactly as they do on screen. It covers both
languages and their regions, prose versus code, the description query, and a
`zg` word that a later session accepts.

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
