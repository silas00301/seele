# Offline flake input report

Run `nix run .#inputs` from a checkout to inspect its `flake.lock`. The report
reads the local file; it never fetches inputs, evaluates their modules, changes
the lock, or inspects authentication configuration.

- `nix run .#inputs -- nixpkgs` shows one direct input.
- `nix run .#inputs -- seele-shell/nixpkgs` resolves a nested input path.
- `nix run .#inputs -- --all` includes reachable transitive dependencies.
- `nix run .#inputs -- --json` emits full revisions and structured metadata.
- `nix run .#inputs -- --lock-file /path/to/flake.lock` inspects another lock.

Input paths and `follows` resolve from the lock's declared root. Repeated nodes
are expanded once, with references identifying their first expansion, so a
shared or cyclic dependency graph cannot produce an unbounded report. A
specific input path can still be inspected directly. Invalid references and
unresolvable follows cycles report an error.

The dates come from the lock's source modification timestamps in UTC; they are
not the time someone last updated the lock. Path and tarball inputs may have no
revision. Source labels omit URL user information, query strings, and fragments.
Human-readable revisions are abbreviated to 12 characters; JSON retains the full
pin. The JSON report is selected metadata, not a raw dump of lock nodes.

The Rust binary `seele-inputs` belongs to
`seele-shell/projects/config-tools/src/inputs.rs`. Build `seele-config-tools`,
then run `python3 seele-shell/projects/config-tools/tests/inputs.py
seele-shell/target/debug/seele-inputs` from the parent checkout. The isolated
fixture is also exposed through `checks.<system>.inputs-report`.
