# Fish command assistance

The `shell-ai` package backs two modes in the managed Linux Fish prompt:

```text
how "delete Nix generations older than 30 days"
debug
```

Pressing Enter on either line asks Pi for one or more commands. One result replaces
the current Fish buffer. Several reasonable interpretations open in fzf first.
Nothing is executed automatically. A destructive result is inserted as a comment,
so running it requires reviewing the command and deliberately removing the comment
marker.

`how` sends the request plus a bounded view of the current directory, available
commands, repository type, platform, and development-shell presence. `debug` adds
the last failed foreground command, its exit code, and its stderr. The collector
does not read project files, the clipboard, environment values, or shell history.

Ordinary interactive Fish sessions run behind a stderr pseudo-terminal so programs
keep terminal behavior and color. Pre/post-exec events delimit the current command.
Only the latest failure is retained, under a mode-0700 directory in
`$XDG_RUNTIME_DIR`, and the whole session directory is removed when Fish exits. Pi
runs without tools, a saved session, extensions, skills, prompt templates, or
project context files.

Run the source checks without a Nix build:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 test_shell_ai.py shell_ai.py \
  ../../features/programs/shell-ai.nix
```
