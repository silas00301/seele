# Shared Codex inference

The native Rust broker and health executables live in
[`seele-shell/projects/broker`](../../../seele-shell/projects/broker/README.md).
That README owns the protocol, isolation policy, resource limits and validation.
The parent re-exports the submodule package; its Home Manager feature owns socket
activation, the configured model, concurrency and health registration.
