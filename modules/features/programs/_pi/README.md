# Pi footer integration

The shared Rust UI library owns usage aggregation, token/path formatting, safe
text, pill composition, priorities and width planning (`qml-core/src/pi.rs`). A
small stable Node-API binding loads it in Pi's process through the `node-core`
package. Rendering starts no subprocess and copies no message content: only
usage counters and the metadata already displayed in the footer cross the ABI.

`status-bar.ts` retains Pi's required `ExtensionAPI` callbacks and opaque session,
theme, terminal-width and truncation objects. It paints the same rounded pills
with Pi's own theme and terminal engine. Branch usage is cached by session/leaf
identity, and one completed rendered line is reused until its inputs, width or
theme invalidation change. Jujutsu queries remain at lifecycle boundaries;
stale session queries cannot replace the current footer, and refreshes coalesce.
The native `seele-pi-jj` helper bounds each fixed Jujutsu read to two seconds and
64 KiB, owns process-group cancellation, and emits only bounded metadata. Pi
receives no subprocess diagnostics; its unbounded capture API sees only this
small native reply.

Rust strips terminal programs, including OSC/DCS and incomplete payloads,
controls and invisible directional formatting before measuring or painting.
Only known thinking-level theme keys are selected. External strings and pill
counts, native JSON bytes, tree depth and output bytes are bounded. Theme-owned
escape sequences are applied after sanitization and retained in the host cache.
No footer data is persisted or sent to a service.

`checks.pi-footer` bundles the adapter and runs `test-status-bar.cjs` against the
real native addon, proving branch invalidation, unchanged-render caching and
hostile metadata handling. The addon has its own byte/type/error/Unicode,
allocation-ownership and worker-isolation tests. Native tests cover numeric
rounding and footer policy. `test-status-layout.cjs` accepts a saved reference
bundle, the new bundle, the addon path and Pi's actual TUI module; it compares
2,002 complete ANSI renderings across Unicode, token/context thresholds,
terminal programs and widths from 0 to 500. The original implementation is not
shipped as a second policy implementation.

This host adapter belongs to the explicit interactive Pi application. Shell
assistance and failure analysis use the native Codex broker and do not run Pi.
