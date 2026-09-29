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
