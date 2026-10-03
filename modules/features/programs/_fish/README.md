# Fish helpers

`edit [ARGUMENT...]` opens the configured `EDITOR`, including optional flags and
quoted arguments such as `nvim --clean` or `'path with spaces/editor' --wait`.
An unquoted complete executable path containing spaces remains supported too.
`EDITOR` keeps precedence even when `VISUAL` is set. With no arguments the editor
opens normally; its exit status is returned unchanged.

Editor words use Fish's non-expanding tokenizer: quotes and escapes group words,
but variables, globs, command substitutions and shell operators are passed
literally. Like Fish's native editor helpers, the tokenizer tolerates unfinished
quotes; balanced quotes are recommended. Use a wrapper executable when the editor
needs shell logic. File
arguments are never parsed as shell source and standard input reaches the editor
unchanged. The helper retains the editor's own option semantics; use
`edit -- -filename` when that editor supports `--` to open an option-looking filename.
An unset, empty or whitespace-only `EDITOR` reports an error instead of treating
a filename as a command.

Run the private native Fish fixture without personal configuration:

```sh
python3 modules/features/programs/_fish/test_edit.py modules/features/programs/_fish/edit.fish fish
```

It covers editor flags/quoting, complete paths with spaces, literal filenames,
no-file launches, missing configuration, non-expansion, standard input and exit
status. The same fixture is the `fish-edit` flake check.

`croot` jumps to the current Jujutsu workspace or Git worktree root. Its separate
`test_croot.py` fixture uses private real VCS repositories; see the `fish-project-root`
flake check in `fish.nix` for its arguments.
