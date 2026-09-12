---
name: seele-shell
description: Develop Seele Shell and carry its Jujutsu-managed submodule changes through validation, commit, push, parent gitlink refresh, lock update, and rebuild-ready verification. Use for changes under seele-shell/ or when shell work must become consumable by the parent Seele flake.
---

# Seele Shell workflow

Treat `seele-shell/` and its parent as separate Jujutsu repositories. Use `jj -R seele-shell` for submodule history, and keep Git's staging area out of both workflows. The repository-owned parent helper uses Git internally because Jujutsu does not snapshot submodule gitlinks.

## Protect both working copies

Run from the parent root:

```sh
jj status
jj -R seele-shell status
jj -R seele-shell log -r '@ | @- | main | main@origin' --no-graph
```

Record pre-existing changes in each repository. Keep unrelated paths out of commits. A detached submodule HEAD is normal.

## Work and validate inside the submodule

Keep UI and runtime behavior in `seele-shell/`. Put parent-side service, package, theme, or Home Manager integration in the parent flake.

`nerv` runs a Lua Hyprland configuration, so anything in `projects/tools/` that
reaches the compositor issues one `hl.dsp` call — `hl.dsp.window.close({ window
= "address:0x…" })`, not `dispatch closewindow address:0x…`. hyprctl exits zero
on the Lua error the legacy form raises, so a wrong call is invisible until the
action is tried by hand.

## Share native runtime and package policy

All first-party service/helper crates use the root `Cargo.toml` workspace and
`Cargo.lock`. The shared `projects/runtime` library owns bounded subprocesses,
process groups and terminal handoff, cancellation, private atomic files,
peer-verified framed Unix sockets, timestamps, redaction and inference lifecycle.
Its `codex` module owns tool-free feature discovery and exec/resume policy.
Broker, prompt and consent-driven consumers must reuse that policy. A successful
clipboard/desktop launcher handoff may deliberately retain its background owner;
use the explicit detaching process API only for those known launchers.

`packages/core/native.nix` builds each native package and runs its fixtures
against unwrapped binaries. Keep executable PATH wrappers at integration
boundaries and Python/Node confined to test/build inputs. The root package map
and the parent `mkNativePackage` export consume that builder, not independent
Cargo locks or copied build flags. The builder derives its source entries from workspace members; add the new
member and its package/fixture mapping once. Build/test commands run from the shell root:

```sh
cargo test --workspace --all-features --locked
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
```

Use the narrower `-p seele-<crate>` during iteration. Crate READMEs under
`projects/{broker,maintenance,prompt,integrations,failure-analysis,shell-ai,config-tools,desktop-tools,repo-tools,qml-core,markdown-core,node}`
name protocol and terminal fixtures. Python fixtures use temporary private state
and fake dependencies; dynamically generated shebangs must use resolved tool
paths so the same checks work in a Nix sandbox. Run the real-Codex loopback
fixture for changes to shared isolation, proving the wire tool list is empty
without contacting a model account. Cargo checks do not establish compositor
rendering or Nix packaging; finish with the affected native package and QML checks
where those tools are available.

All UI packages and development checks receive one pinned Quickshell derivation
from `packages/core/quickshell.nix`. Keep local host fixes there: the current
NetworkManager patch validates wire modes before narrowing and provides a
complete fallback. Its build runs `tests/quickshell-network-mode.py` over actual
upstream function bodies with UBSan. Override `upstream.unwrapped` and rebuild
the outer Qt wrapper; patching only that wrapper cannot change the executable.
See `seele-shell/docs/native-workspace.md` for the shared host and ABI contracts.

Pi/OpenCode status extensions share `projects/shell/status-hook.ts`; only their
host event bindings remain TypeScript. The package bundles each adapter with an
explicit native `seele-agent-hook` path. Rust owns bounded hook input, lifecycle
validation, process identity and private atomic publication. Keep
`tests/harness-status.sh` passing when changing these events. Privileged NixOS
generation activation belongs to `repo-tools/src/generation.rs`; its fixtures
must never activate the test host.

Native lock/greeter/Notes launchers share `projects/tools/src/launch.rs` and
`SEELE_QUICKSHELL`/`SEELE_CONFIG` package bindings. Preserve a successful lock
daemon handoff even if secure-ack IPC times out or the launcher is cancelled.
The launcher only returns success after compositor confirmation; its absolute
five-second acknowledgement deadline includes subprocess time. Run
`cargo test -p seele-tools --test launchers` with synthetic executables after
changing process ownership or launcher packaging.

Pure UI policy lives in `qml-core`; `projects/qml` exposes it through the shared
C ABI and `Seele.Core`. Preserve real JS arrays and own object keys on return:
the bridge uses the engine's captured JSON parser because QVariant conversion
breaks `Array.isArray`, filtering and list-model behavior. `Native.js` and
`ListModels.js` retain only Qt value/object/model binding. Native notifications
have one opaque Rust state per owning Qt object, with no retained event replay.

Pi footer policy uses the same library through `projects/node` and stable
Node-API. TypeScript retains theme painting, Pi terminal width/truncation and
callback lifecycle; unchanged redraws reuse one completed line. The native
`seele-pi-jj` bounds lifecycle probes. Run its process fixtures, the real-addon
`checks.pi-footer`, and the full ANSI differential after policy changes.

Keep all background work and reusable policy in Rust. Preserve UI materials,
geometry, animations, keyboard behavior, source object identity and consent.
Use the pinned nixpkgs Rust version for final formatting/Clippy compatibility;
a newer local compiler is only an iteration aid.

## Keep NixOS generation rollback reviewable and guarded

The managed Vicinae command `generations` lists the retained system profile with
the running system's `nixos-rebuild list-generations --json`. Do not trust its
`current` field to identify the booted configuration: resolve each
`system-<number>-link` and compare it with the canonical `/run/current-system`
target. Put the selected build time first in the detail, followed by its kernel,
NixOS metadata, and an `nvd diff` between the captured immutable running/target
store paths. Show the switch action only after the current review's diff succeeds;
a failed or stale result never authorizes activation.

A switch always gets a destructive confirmation naming the generation. After
confirmation, the native checker resolves the generation and running system
again and requires both identities to match the review. Pass the positive
integer plus both store basenames through the running system's `run0` to
`seele-switch-generation`. The helper repeats canonical identity/ownership
checks after authentication, changes the system profile with the running
`nix-env`, and activates the exact selected closure. It never executes a caller
path, sets `NIXOS_NO_CHECK`, or bypasses switch inhibitors.

The native `seele-control vicinae-*` endpoints prepare desktop/generation/keybinding
snapshots, enforce audio/key input and format immutable diffs. React keeps its
actual host rendering, confirmation and clipboard APIs; Intl/localeCompare keep
host locale semantics. Rendering launches no processes. Preserve
`tests/vicinae-generations.mjs`, `tests/vicinae-keybindings.cjs` and the native tools/repo-tools
fixtures, plus `vicinae-generation-review.cjs` for failed/stale/duplicate confirms.

Rollback and cleanup stay separate. Do not add delete or garbage-collection
actions to the picker; the parent `programs.nh.clean` policy decides retention.
Keep subprocess errors out of toasts. `tests/vicinae-generations.mjs` covers
generation validation, actual-running detection, and safe diff rendering.

## Keep frozen URI picking responsive

`seele-shellctl uris` reaches `UriPicker.qml` and one `seele-shell-uris` layer
surface per output. The separate Rust `seele-uri-worker` owns concurrent Grim
PPM captures, optional exact terminal text, and a bounded pool of warmed
Tesseract engines from nixpkgs. Keep all of that work off the QML thread and
display the exact pixels being recognized.

Use tmux `capture-pane` only for normal visible panes in the focused Ghostty
window. Prove the tmux client descends from the Hyprland window PID through
`/proc`, require nonzero cell dimensions, and accept a logical-pixel mapping
only when the tmux grid fits the window. Copy mode, modal/floating panes, unknown
clients, unavailable sockets, and ambiguous scale or padding must fail closed to
OCR. Map exact boxes output-locally, not in desktop-global coordinates. Parse
URIs, existing explicit paths (`/`, `./`, `../`, `~/`), and 12–64 character
Jujutsu IDs only; canonical paths open and revision IDs copy. Never guess a bare
filename or expose terminal text in diagnostics.

Emit exact terminal items before starting asynchronous OCR so their global
numbers cannot move. Mask only OCR hits whose centers overlap an emitted exact
token. Keep GUI and unsupported terminal OCR active, and never mask the ZBar
whole-output pass for QR codes and barcodes. The Rust grayscale and 1.5×
enlargement pass preserves small URI punctuation; use local adaptive thresholds
for dim address-bar text beside bright browser chrome. Code payloads use exact
decoded text without OCR prose cleanup. Number opens a URI or canonical path and
copies revision or non-URI code text; Ctrl + number copies any item and stays
latched through multi-digit input. Show the default action in the hover text.
Show code text below its box, or above when the output has insufficient room.
Pass clipboard text through stdin to wl-copy and render it as plain text.

An empty scan or failure releases captures and keyboard focus immediately; a
separate click-through status surface shows the result for five seconds. Capture
open shell panels and toasts before covering them, and preserve panel state
across dismissal. Stream results into the retained ListModel, keep numbers
stable across outputs, and wait for the complete number set before auto-opening
a typed number. Enter resolves an exact numeric prefix; never use a timeout to
guess user intent.

Images are private runtime files and are removed on cancellation, EOF, errors,
and graceful termination. Guard messages by generation so an old scan cannot
reopen a dismissed overlay. `tests/uri-picker.sh` exercises exact tmux records,
real OCR, code coexistence, capture identity, strip boundaries, and cleanup;
`tests/uri-picker.js` covers selection, action routing, and badge geometry.

## Keep the quick AI prompt lazy and private

`seele-shellctl prompt` reaches `AiPrompt.qml`; the parent binds it to
`Super + Space`. Keep the QML surface and Rust `seele-ai-prompt-worker` resident so
the panel maps synchronously on the recorded focused output, but never start
Codex or read a context source merely because it opened. The worker's empty
mode-0700 runtime workspace is the model cwd. Use the shared runtime Codex
policy for both exec and resume: disable tools and inherited project/user
configuration as well as selecting the read-only sandbox. Keep the UUID only
in memory, resume
follow-ups only while this panel stays open, and validate the UUID before
passing it to `codex delete --force`.

Explicit user `@mentions` authorize their sources for one Send. Opening or typing
must not read sources, including `@dir`. The QML coordinator collects every
mention before starting one model turn, displays Collecting, and rejects duplicate
Send inputs. `@window` carries only the pinned app/title; `@dir` resolves the
focused terminal. Clipboard and selection use bounded exact text. `@screen`
hides the panel and captures its pinned output, then restores it and submits
without a separate preview step. Keep source-specific one-time approval and
Capture/preview controls for context requested by the model. Failed collection
preserves the prompt and identifies the mention; edits, closing, and reopening
invalidate tokens and remove captures. The production-function tests in
`tests/ai-prompt.js` cover collection, duplicate sends, failures and stale replies.

Context blocks are JSON-quoted reference data and never commands. Keep Codex
argv fixed, pass prompts and clipboard payloads through stdin, and bound
prompt, context, answer, and insertion sizes. Enter sends when input exists
and copies an answer otherwise. Ctrl + Enter hides the panel, focuses the
captured Hyprland address through one `hl.dsp.focus` call, verifies both the
active address and pid, and only then gives the exact answer to `wtype --`.
Closing kills the model process group; turn and deletion workers must survive
long enough to recover and delete a UUID printed just before cancellation.
`projects/prompt/tests/controller.rs` covers privacy gates, stale context, session
reuse, actions, cancellation, and shutdown cleanup against the Rust executable; `tests/ai-prompt.js` covers QML.

## Notification interactions

Keep the September 8, 2026 11:00 CEST behavior from `b728ef05d8bd`: native
notifications, in-place app stacks, and the Current/History view selector.
Notification search and title/message copying were added later and have been
reverted; `tests/feature-integrations.js` fails if `notificationSearch` or
`notificationClipboard` returns. Verification-code copying remains, and timed
DND was restored on request.

Do Not Disturb has two forms. The header switch silences the shell until it is
thrown back, and the quiet presets — 15 minutes, 1 hour, 4 hours — silence it
until a deadline. `snooze()` stores an absolute `dndUntil` plus the
`dndMinutes` that asked for it, so suspending does not extend the period and
the panel lights the preset that started it rather than guessing from a
deadline that keeps moving. `advance()` ends an expired period without
replaying the toasts it suppressed, `setDnd()` clears both fields because a
manual choice replaces a timed one, and `restore()` drops a period that ran out
while the shell was down. `seele-shellctl notification snooze <minutes>`
reaches the same store; the minute count travels in the `id` argument.

`NotificationStore.qml` owns the desktop notification service through
Quickshell. `projects/qml-core/src/notifications.rs` owns presentation and the
complete state machine in a Rust object owned by a Qt QObject. `notifications.js`
only projects native properties and retains/invokes actual notification objects;
`projects/shared/Native.js` is the shared Qt bridge. Timer ticks pass a timestamp,
not a snapshot of every notification. The engine releases the Rust object when
its owning wrapper is collected.
The parent disables mako; hardware status workers never publish notification
or DND fields. `seele-shellctl notification <action>` and `notification-status`
reach the native store over IPC, and `seele-control` keeps matching commands.

Ordinary toasts default to 30 seconds, pause while hovered, and retire without
closing the inbox entry. Respect positive sender timeouts for the toast;
critical, explicitly non-expiring, and user-pinned toasts stay until hidden.
Resident means actions do not close the notification, independently of its
toast timeout. Transient notifications skip the inbox and history and expire
through the protocol. Only explicit dismissals enter the bounded 24-hour
history. Keep DND, history, timestamps, and pins across QML reloads through
`PersistentProperties`; never persist message text or codes to disk.

Both views group by desktop entry (falling back to app name), show overlapping
cards, and expand independently. Toasts have individual card material with no
shared backdrop. An individual toast's close hides it; panel dismissal closes it.
The stack lead's close dismisses its whole group in either view, folded or
expanded. Named
actions, including Reply, invoke the sender's app interface. Verification codes
copy explicitly without dismissal. Preserve urgency, local images, progress,
markup, links, action icons, and replacement IDs/tags. Treat a local
`Notification.image` as sender identity: place it in the card's leading rounded
slot, badge the sending `appIcon` at its lower-right corner, and do not repeat
the image as expandable body media. Keep the application icon in the leading
slot while the image loads or if it fails. Only advertise capabilities that are
rendered. At the pinned Quickshell revision, `expireTimeout` exposes raw D-Bus
milliseconds despite its seconds documentation.

`tests/notifications.js` exercises image roles, the state machine and grouping
through the native fixture CLI. Its replay transport is test-only; production
never retains events. `tests/tst_nativefunctions.qml` exercises the real Qt/Rust
object boundary. `projects/qml-core/README.md` documents memory bounds, Qt locale
collation and the reproducible resident-state benchmark;

`tests/notification-server.sh` runs a windowless Quickshell on a private D-Bus
session to check the real API and production IPC handlers during the package
build. `tests/control-actions.sh` checks command and clipboard failures.

## Preserve status model identity

`projects/shell/SystemState.qml` owns the status fields and their startup
values. Feed snapshots and optimistic patches through `apply()` so each field
notifies independently and unchanged JSON branches retain their identity. The
Rust `system.patch` schema validates allowed fields/types; the Qt adapter retains
actual engine object references and emits only the affected notify signals.
Replacing the whole state object makes unrelated bindings rerun and rebuilds
list delegates. Add new backend status fields to this component as well.
`tests/system-state.sh` checks signal counts, delegate reuse, and unchanged
rendered pixels; both `test-shell` and the main package build run it.

Performance work keeps rendering components, visual tokens, and motion timing
unchanged unless the user asks to change their appearance or pace.

The shell reads field patches from `seele-control watch-status`. Guard callback
side effects on the presence of their field: an audio update carries neither
headphones nor notifications. `projects/tools/src/live.rs` owns D-Bus listener
reconnects, a buffered PipeWire monitor, and the five-second ancillary refresh.
NetworkManager and BlueZ signals trigger source-specific probes. Notification
QObjects belong to the QML store; history and DND policy belong to its resident
Rust state object. Explicit stdin requests
return complete source fields even when unchanged so optimistic controls can
settle. Keep that acknowledgement separate from unsolicited deltas.
`projects/tools/tests/live.rs` runs against a private bus and mock probes;
`tests/status-patches.js` exercises the shell's actual partial-update callback.

`seele-clock watch` caches static timezone metadata for the current database,
year, and locale, but computes times, offsets, and pins on every `refresh` line.
Both workers exit on stdin EOF. Clock's timezone conversions remain in its own
single-threaded process because libc's `TZ` state is process-global.

## Notes captures into a vault it does not own

`projects/notes/` is a separate desktop app, not a shell panel, and it is a
quick-capture front end for Obsidian rather than a second library. The
configured folder of the vault **is** the store: a note is an ordinary Markdown
file there, and there is no index, database or mirror beside it that could
disagree with the bytes on disk. Obsidian keeps the knowledge base, the graph,
the plugins and vault-wide moves; this owns the thirty seconds between having a
thought and having it written down. Leave vault-wide renaming and backlink
maintenance to Obsidian.

The `notes` output provides `seele-notes` and `seele-notes-store`; the parent
exports `seele-notes` and installs it through its own
`flake.modules.homeManager.seele-notes` feature. Reopen the existing process
through IPC. The shellctl/Vicinae launch must detach so a launcher's command
timeout cannot kill the app.

Nothing Seele needs for itself goes into the vault. The user's chosen vault and
folder live in `$XDG_CONFIG_HOME/seele-notes/settings.json`, written by the
app's own directory picker; the parent flake may install a read-only
`config.json` beside it as a default, and the picker's choice wins. Trash
metadata, recovery drafts and the migration index live under
`$XDG_STATE_HOME/seele-notes/`. Trashed notes move into the vault's own
`.trash`, and restore is collision-safe against whatever took the name.

`Library::save` takes the digest the draft was loaded from. A digest, not an
mtime: filesystems differ in granularity and sync tools rewrite timestamps, but
the bytes either changed or they did not. A stale digest is a conflict, never an
overwrite, and the three ways out — save a copy, keep mine, use theirs — each
keep both versions. A file that vanished elsewhere answers `gone` rather than
being recreated by an autosave already in flight. Text the filesystem refused is
kept as a recovery draft; a request that was never valid is not. Saving text
identical to what is on disk rewrites nothing, so opening and closing a note
leaves its mtime alone.

A new capture is a document, not a file. Nothing is written until there is
something to write, so an abandoned empty draft leaves nothing behind, and the
filename is earned once from the first meaningful line and never changed by a
later body edit. Recordings are vault files in the attachment folder, referenced
by Obsidian embeds on their own block — a line directly under a paragraph is a
lazy continuation of it and renders inside the sentence. Removing an embed edits
text and never deletes audio another note may reference.

The worker watches the folder with inotify and coalesces a refresh. A reply that
already carried the listing clears the pending refresh, so the watcher's echo of
our own write is not replayed as an external edit; a reply that did not carry
one leaves it alone. A clean note follows the file, a note being typed into is
never reloaded under the caret, and re-reading the note already on screen keeps
the caret and the scroll position.

The editor is live Markdown over the exact bytes. `Seele.Markdown` is a small
Qt QML module in `projects/markdown/`: `MarkdownHighlighter` applies character
formats to the `TextArea`'s document without touching its text, so frontmatter,
wikilinks, embeds and anything it does not model survive being edited around,
and the caret, the selection and the undo stack survive every autosave, search
update and syntax repaint. Qt's `MarkdownText` mode is not an option — it parses
into rich text and re-serializes on the way out. Syntax characters are dimmed
rather than hidden, which is what keeps them editable at the caret. Source mode
detaches the highlighter, and only the highlighter: the same bytes, set
uniformly. Detaching opens an empty edit block that Qt reports as a content
change, so the editor only reports an edit when the text actually differs.

`MarkdownEdit::replace` applies an editing command inside one `QTextCursor`
edit block. Applying it through `TextArea`'s own insert and remove costs two
undo steps and passes through a document the writer never saw. Every command in
`notes.js` is one replacement plus a caret, so it stays testable in Node and the
editor only has to apply it.

The recorder owns its `parecord` child and must finalize on Stop, EOF, and
SIGTERM, reap the child, and salvage whatever it captured before a failure.
Playback lives in a separately loaded QtMultimedia component. Build both
`default` and `notes` when shared QML changes.

Run `tests/notes.py` with the raw `seele-notes-store` helper — it drives real
Markdown files, external edits, conflicts, trash collisions, a relocated vault
and migration idempotency — plus `tests/notes.js` and `tests/notes-store.js`,
the latter exercising production QML store callbacks. `tests/notes-editor.sh`
runs `tests/tst_noteseditor.qml` under `qmltestrunner`: real key presses into
the production editor for focus, list continuation, undo, the caret across a
refresh, and a pixel comparison proving the highlighter draws something the
source does not. `tests/dictation.py` checks the native audio bridge against a
fragmented/reconnecting Voxtype socket. Dictation follows the daemon's JSON
status and native audio frames; never open a second capture just for levels.
Keep the overlay on its starting output and leave focus and pointer input alone.

Clock sources merge both tzdata city tables and its backward aliases. Refresh
clock rows at minute boundaries and panel opening, using one snapshot for time,
date, and offset. Calendar models depend on the date, not the seconds tick.
Keep ISO week arithmetic in UTC and local clock display in the system timezone.

## Draw from the shell's design tokens

`projects/shared/Theme.qml` owns the shell and Notes visual vocabulary. Both
entrypoints inherit it, and shared components receive it as `theme`. The shell
keeps thin inline aliases for its existing instances — `component X:
Shared.X { theme: root }` — so shell code writes `X { }` unqualified while the
component itself, and its reasoning, live in `shared/`. Put a part there as
soon as a standalone application could want it; `SectionRule`, `SegmentWell`,
`Segment`, `IconButton`, `MeterBar` and `ControlSwitch` moved out of `shell.qml` for exactly
that reason. Quickshell rejects local imports that escape a packaged config
root, so each package installs its own `shared/` directory below that root and
rewrites the source tree's sibling import to `import "shared" as Shared`; keep
an install check for that layout. The Notes package globs
`projects/shared/*.qml`, so a new component needs no packaging change but must
pass that package's `qmllint`. The shell package instead names each file twice,
once to install it and once in its `qmllint` line, and the two lists drift apart
silently: `MaintenancePanel.qml` and `MaintenanceStore.qml` shipped unlinted long
enough for that surface to grow its own formatting and rebuild parts the
vocabulary already had. Add a new shell QML file to both lists.
Every surface reads from that block rather than deciding for itself:

- **Type** — `textMicro` through `textHero`. Steps are named for the role they
  play. A glyph normally takes the step above the text beside it; a glyph set
  in a well takes the step below, because the well carries the weight.
- **Weight** — `weightLight`, `weightRegular`, `weightMedium`, `weightStrong`.
  Nothing sets `font.bold`.
- **Tracking** — `trackingLabel`, for uppercase section rules only.
- **Space and size** — `spaceTight` through `spaceLarge`, `cardPadding`, and the
  three control heights `chipHeight`, `controlHeight`, `rowHeight`, beside the
  existing `radius`, `panelMargin`, `panelSpacing`, and `panelHeaderHeight`.
- **Elevation** — `panelColor`, `cardColor`, `rowColor`, `wellColor`,
  `floatColor`, `cardBorder`, and `separatorColor`. Depth is built out of one
  ink, `crust`: chrome is cut out of the wallpaper with it and wells are cut
  back to it.
- **Edges** — `panelBorder` grounds a surface in that ink, `edgeLight` is the
  hairline of light inside it, and `edgeCrown` is the brighter line along the
  top. No edge carries the accent.
- **Interaction** — `hoverColor` is the neutral light wash that reports the
  pointer. Apply it directly only over transparency; a filled control uses
  `hoveredColor(<resting fill>)` so the wash remains visibly composited over
  its material. `pressColor`, `selectedColor` and `activeTint` report state in
  accent. A state that is not hover never borrows `hoverColor`. An animated
  fill that rests on nothing rests on `clearColor`, or on `clearDanger` where
  the state it fades from is red — never on `transparent`, because Qt
  interpolates a colour channel by channel and `transparent` is black, so a
  tint animated against it is dragged through grey at both ends of the fade.
- **Motion** — `durationFast` for an in-surface tint, `durationNormal` for a
  control that travels.

Assemble a surface from the shared components rather than repeating their
parts: `PanelHeader` (glyph or `mark` in its accent well, title, optional
detail, trailing slot), `SectionLabel`, `SectionRule` (that label with the
group's live summary at the far end and, where the group folds, the chevron and
the click target that fold it), `SegmentWell` with `Segment`, `IconButton`,
`HoverWash`, `MeterBar`, `CardEdge`, `PanelSurface`,
`SurfaceWash`, `SurfaceEdge`, `SurfaceGrain`, `SlimScrollBar`, `ControlSwitch`,
`RefreshGlyph`, `CenteredGlyph`, `HoverTip`, `BarItem`, `BarLabel`, `ControlTile`,
`ConnectivityRow`, `ControlLevel`, `MediaButton`, and `MediaBody`. A framed surface takes
all three of `SurfaceWash`, `SurfaceEdge` and `SurfaceGrain`, in that order:
the wash under the content, the edge and the film over it.

A `HoverTip` on a control inside a panel needs `inOverlay: true`; without it the
menu bar's guard hides the tip whenever the panel is open.

A card, row or tile that reports the pointer takes that state from a
`HoverHandler` on the surface itself, never from a covering
`MouseArea.containsMouse`. Qt hands a hover event to one item, so a control the
surface carries takes it away from the area underneath and the surface goes
cold under a pointer that is still on it. Keep the `MouseArea` for the click
and the press — including where it is deliberately inset, as the Tailscale
card's is to leave its switch alone — and ask the handler whether the pointer
is there. The control doing the stealing is often not written inline: the
Control Center's audio card is covered by two `ControlLevel` instantiations,
each a hover area, and a `ModuleDragArea` is a `MouseArea` under another name,
so grepping for `MouseArea` misses both.

Two more ways a surface goes quiet under the pointer. A fill that branches on
state before hover — `active ? accent : hovered ? ...` — can never report a
pointer on an active control; lay the neutral hover wash over the state as its
own child instead of making it another branch. And a highlight inset inside its
row leaves a dead line above and below itself, which the spacing between rows
widens into a band; a row highlight takes the row's full height.

The Control Center's media module and the Now Playing panel it opens draw the
same `MediaBody` at the same `mediaBodyHeight`, so there is one place to change
what a track looks like. The card wraps it in a module surface with hover and a
`ModuleDragArea`; the panel puts it under a `PanelHeader`. Neither arranges the
parts itself. Their player comes from one root selection. The panel exposes that
selection through `MediaPlayerPicker` when more than one resumable player is on
the bus, and the Control Center follows it.

Hover cannot be verified by warping the cursor with `hl.dsp.cursor.move`: the
compositor delivers a pointer event only when the warp crosses into a different
surface, so consecutive moves inside one panel leave the shell reading the first
position. Bounce off an unrelated surface between samples, then diff `grim`
captures against a pointer-away baseline.

The AI cockpit is a readout. Its session row is one card with a cell per
harness — a lit dot and a name, beating only while that session works or waits,
a well in the card while nothing runs — and no cell answers a click, so none of
them takes the pointer cursor. `agentIndicators()` is what the row draws: the
launchers CodexBar reports, plus any harness that published lifecycle state
without one. A lit cell answers the pointer and focuses its
session through `seele-control agent-focus`, which walks the record's pid up
through `/proc` to the terminal holding it; a finished record has no window
left, so only a running session takes the pointer cursor. Launching lives in
`seele-agent`, `seele-shellctl agent`, the `launchAgent` IPC method, and the
menu bar entry's right click, not in the panel.

`AgentMark` draws a harness or provider as its own vendored SVG, rasterized
well above the size it is drawn at because the OpenAI knot loses its loops in a
24px raster squeezed into the menu bar. `agentMark()` maps an id to a file and
returns an empty string for anything unknown, which falls back to
`agentBadge()`'s two letters. The marks are flat: state belongs to the beating
bar under a badge and to the tier colour on a capacity's number, not to the
mark. Adding one means the SVG beside `shell.qml`, an `install` line and the
`installCheckPhase` mark loop in `package.nix`, and an entry in `agentMark()`.

Size a panel from its content — `implicitHeight: <content>.implicitHeight +
root.panelMargin * 2`, with the content column anchored left, right and top.
Where a panel must state a height, build it from the tokens rather than a
counted constant, and derive any viewport inside it from the same terms.

`projects/lock/`, `projects/greeter/`, and `projects/polkit/` are separate
clients that mirror the subset of non-palette tokens they use. Their roots take
fallback palette values and JSON assignment from `projects/shared/Palette.js`,
which each package copies beside its root; do not restore local Catppuccin values
or assignment loops. Keep another shared token identical to the shell's, and
drop it from a client block when nothing there reads it.

A palette colour a client reads has to arrive from the parent as well: the
generated `theme.json` in `modules/features/programs/seele-shell.nix` and
`seele-greeter.nix` carries the named palette entries, and a client that reads
a new one needs both the key there and the assignment in its own `FileView`.

The grain film is generated at build time by `seele-tools grain`, in
`projects/tools/src/grain.rs`. It is a seeded two-octave tile — fine noise
drawn as the mean of several samples, clumped by a coarse wrapping octave —
and both octaves wrap, so the tile stays seamless. Tune `grainOpacity` with it:
a finer film needs a little more of it to read at all.

Use the narrowest package build that contains the change:

```sh
cd seele-shell
nix build .#default --no-link --no-write-lock-file
nix build .#notes --no-link --no-write-lock-file
nix build .#greeter --no-link --no-write-lock-file
nix build .#lock --no-link --no-write-lock-file
nix build .#polkit --no-link --no-write-lock-file
```

The default package build compiles the Rust tools, runs `qmllint`, bundles the extensions, and runs the focused shell tests. `tests/shell-load.sh` also compiles the complete production QML through Quickshell on a private headless Sway compositor. It does not instantiate the desktop, start workers, or access the session bus. The lock package runs the same compile check. Keep its startup timer beside
`WlSessionLock`: the lock's default property is its single surface component,
not a container for arbitrary objects. Keep this runtime check: `qmllint` missed a nonexistent property assigned through an inline shared-component alias, and the built shell could not start. `tests/feature-integrations.js` also proves that independently tested feature helpers remain wired into production `shell.qml`, installed by the package, and covered by its install checks; extend it when a feature adds another production seam. Build every affected output when shared code changes. Use `nix develop -c test-shell` for a faster Rust and JavaScript loop, but finish with the relevant package build.

Inspect the submodule diff before crossing back into the parent:

```sh
jj -R seele-shell diff
jj -R seele-shell status
```

## Commit and push the submodule

Commit and push only when the user asked for a rebuild-ready result or otherwise authorized those history and remote changes.

Commit only the intended submodule paths. Jujutsu leaves every unselected change in the new working-copy commit:

```sh
jj -R seele-shell commit <paths> -m "<shell change>"
jj -R seele-shell status
```

Fetch the remote bookmark and inspect it against the new commit:

```sh
jj -R seele-shell git fetch --remote origin
jj -R seele-shell log -r 'main@origin | @-'
jj -R seele-shell log -r 'main@origin ~ ancestors(@-)' --no-graph
```

An empty result from the final command proves the push will be a fast-forward. If it prints a commit, rebase the local stack onto `main@origin` and resolve any conflicts before continuing:

```sh
jj -R seele-shell rebase -s 'roots(main@origin..@-)' -d main@origin
```

Move the local bookmark to the commit and push through Jujutsu's remote safety checks:

```sh
jj -R seele-shell bookmark set main -r @-
jj -R seele-shell git push --remote origin --bookmark main
jj -R seele-shell status
```

The parent helper requires a clean submodule, so leave the boundary here if unrelated submodule changes remain. Never discard or commit those changes just to satisfy the helper.

## Refresh the parent pointer

Return to the parent root and run:

```sh
nix run .#update-submodule
```

The helper verifies that the submodule is clean, commits only the parent gitlink through Git, imports that commit into Jujutsu, advances `main` to it when possible, and refreshes the shell's transitive inputs in the parent lock. Do not stage the parent gitlink manually. The `seele-shell` input is a path inside the parent flake, so the gitlink pins its source revision and source-only shell updates leave `flake.lock` unchanged.

For an explicitly authorized pull request, publish the clean shell revision on
its PR bookmark first and commit the companion parent changes. Use the native
helper's PR mode from the parent root:

```sh
seele-shell/target/debug/update-submodule --pr --keep-lock
jj bookmark set <parent-pr-bookmark> -r @-
jj git push --remote origin --bookmark <parent-pr-bookmark>
```

`--pr` requires detached Git HEAD and leaves every bookmark, including `main`,
unchanged. It still verifies that the child revision is published and commits only
the gitlink. `--keep-lock` is permitted only with `--pr`: it checks byte-identical
old/new child `flake.lock` blobs and an unchanged tracked parent lock in both the
index and working tree before mutation. Review the child input declarations
independently before choosing this option. It skips Nix entirely and explicitly
reports that neither evaluation nor lock refresh ran; it does not prove the
result rebuilds. Without `--keep-lock`, PR mode performs the normal lock refresh.
Use the already built helper directly when Nix is unavailable; never install Nix
against a user constraint. Never advance or push `main` for a PR-only request.

Review the resulting parent state:

```sh
jj status
jj diff
```

If the lock or companion parent code changed, commit only those paths before advancing and pushing `main`:

```sh
jj commit flake.lock <companion-parent-paths> -m "Refresh Seele Shell"
jj bookmark set main -r @-
jj git push --bookmark main
```

Omit `flake.lock` when the shell's transitive inputs did not change, and omit `<companion-parent-paths>` when there is no parent-side code. If neither changed, the helper's gitlink commit is ready to push. Keep unrelated paths in the working-copy commit.

## Prove the parent consumes the new revision

The gitlink must match the pushed submodule commit, and the lock must keep the relative path input:

```sh
shell_rev="$(jj -R seele-shell log -r @- --no-graph -T commit_id)"
gitlink_rev="$(git ls-tree main -- seele-shell | awk '$1 == "160000" { print $3 }')"
lock_path="$(jq -r '.nodes["seele-shell"].locked.path' flake.lock)"
test "$shell_rev" = "$gitlink_rev"
test "$lock_path" = "seele-shell"
```

Then run the parent Seele validation workflow. At minimum, format the parent, evaluate the flake and native host, build `packages.<system>.seele-shell`, and build the native host closure. A rebuild-ready result has a clean pushed submodule, a matching gitlink, the relative path lock with refreshed transitive inputs, passing submodule and parent builds, and a pushed parent bookmark.

Activation is separate. Run `nh os switch`, `nh darwin switch`, or an equivalent activation command only when the user explicitly asks to change the live machine.

Shared palette changes must keep `projects/shared/Palette.js` beside every
consumer. Shell/Notes packages and isolated Qt fixtures copy shared `.qml` and
`.js` assets together; auth-client packages copy Palette.js beside shell.qml.
Run `node tests/palette.js ...` and the offscreen `tests/palette.sh` fixture.
Palette data/property assignment is a necessary Qt API boundary, with no service
or background logic. Preserve existing theme and wallpaper assignment semantics.
