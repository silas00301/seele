# Contextual shell history

`modules/features/programs/atuin.nix` keeps Ctrl-R as Atuin's global fuzzy
history search. Up uses a prefix search restricted to the current directory.
Atuin's native Up handler preserves multiline editing and Fish's search/pager
fallbacks. Selecting a command with Enter or Tab puts it back into the prompt
for editing; it does not execute the command immediately.

The common profile and portable Fish already import the Atuin feature. The
standalone portable `atuin` output also carries its settings. Other shells keep
their existing Home Manager integrations.

## Fish binding ownership

The pinned Television integration binds Ctrl-T and Ctrl-R. FZF yields Ctrl-R
through `historyWidget.command = ""`, but that does not disable Television's
history binding. Atuin therefore declares Ctrl-R in Fish's `default` and
`insert` maps with `programs.fish.binds`. Home Manager renders these into the
standard `fish_user_key_bindings` function, preserving the module-level merge
of other declared bindings.

`programs.fish.shellInitLast` invokes that same function after the integrations
have loaded, only in an interactive shell. Fish also calls the standard user
hook when `fish_key_bindings` changes; its vi and Emacs setup functions erase only preset
bindings. No extra event handler or second Atuin integration is needed, and
Television retains Ctrl-T.

## Validation

With the built configuration, inspect both maps:

```fish
bind --mode default ctrl-r
bind --mode insert ctrl-r
bind --mode default ctrl-t
bind --mode insert ctrl-t
```

Both Ctrl-R bindings should invoke `_atuin_search`, and Ctrl-T should invoke
`tv_smart_autocomplete`. To refresh managed bindings in an existing shell, use:

```fish
source $__fish_config_dir/functions/fish_user_key_bindings.fish
fish_user_key_bindings
```

Repeat the binding checks after switching `fish_key_bindings` between
`fish_default_key_bindings` and `fish_vi_key_bindings`, and in a new Fish session.
Home Manager guards its generated `config.fish` with `exit` when it is sourced
twice, so do not source that whole file to reload these bindings.
Check that Up still edits multiline commands normally,
that its first-line history search is directory-scoped and prefix-based, and
that Enter restores the selection to the prompt.

The settings and hook behavior were checked against the pinned Home Manager
`2c0350c7`, Fish 4.9.2, Television 0.15.9, and Atuin 18.19.0 sources. In an
environment without Nix/Fish/Atuin, source inspection does not replace these
runtime checks; report that validation boundary explicitly.
