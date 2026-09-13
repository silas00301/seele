# Fish command assistance

The parent package consumes `inputs.seele-shell.packages.<system>.shell-ai`.
The Rust implementation, tests and runtime/security contract live in
`seele-shell/projects/shell-ai/`.

`modules/features/programs/shell-ai.nix` keeps the existing Enter interception,
private capture hooks, and one prompt replacement path for both `how` and `debug`.
The resident Rust wrapper now keeps the last failure exclusively in memory and
serves it over a private per-session socket; terminal output no longer triggers
filesystem writes. Explicit generation uses the common Codex broker, removing
Pi, Node and Python from this package. No command is automatically executed.

Run `cargo test --manifest-path seele-shell/projects/shell-ai/Cargo.toml` and
`cargo clippy --manifest-path seele-shell/projects/shell-ai/Cargo.toml
--all-targets -- -D warnings`. The parent `shell-ai` check builds the submodule
package and its Rust tests. Native Nix/Fish terminal validation remains required
before activation; this migration neither installs Nix nor activates the host.
