# Seele Shell integrations and controls

Shell features remain in the `seele-shell` source repository; the parent consumes
its published revision through the existing gitlink/path input. Source-only
changes do not change `flake.lock` when the shell's inputs and lock are unchanged.

## GitHub

`seele-shellctl control github` opens Notifications, Reviews and My pull requests.
The resident `seele-github-inbox` worker in `projects/integrations/src/github/`
paginates unread API notifications in the background (GitHub lists web-Done
threads among read ones and exposes no Done state), collects thread/comments and
review/CI metadata without changed files or diffs, and submits automatic triage to
the shared Codex broker. The broker owns model choice. Raw entries remain usable
while triage is pending or failed; only the two urgent priority classes produce
desktop notifications, whose action unfolds that thread's row in the panel. Rows
carry priority as a `StatusChip` and grow in place rather than swapping the list.

Done is explicit and optimistic, with rollback on GitHub failure. Public APIs
expose no saved state, Save/Unsave or Undo-Done; Silas approved deferring those to
the web inbox for SIL-40. Never pretend a local-only action synchronized them.
Source text and triage stay in memory; only account-scoped IDs/revision
fingerprints persist privately for Done and alert reconciliation. Opening a row
never marks read. QML retains model identity and keyboard focus.

The PR tabs retain `projects/runtime/src/github.rs`, `GitHubStore.qml` and their
bounded read-only collector/display policy. Keep credentials out of QML, broker
payloads, logs and arguments. Reuse the existing `gh` login and fixture/fake-gh
tests rather than a real account. See `projects/github/README.md` for public API
boundaries, account settings, native tests and the rendered Qt inbox fixture.

## Home Assistant

`seele-shellctl control home-assistant` opens the always-visible house entry's
panel. `HomeAssistantPanel.qml` owns setup, selected devices, room groups,
favorites, light sliders, fan power/speed and the optional menu bar reading.
Every selected sensor has a named readout in its room card or Favorites,
including unavailable readings. Supported control domains keep their rows while
unavailable; current controllability only gates actions. The worker preserves
the sanitized device classes consumed by the presenter. The picker separates
Your devices and Add devices;
names and rooms save together. Preserve nested list identity across live updates,
and keep an active slider drag independent of incoming state. Focused controls
scroll into view; the panel body is bounded by its opening output.

`projects/integrations/src/home_assistant/` owns private metadata, Secret Service
access and the resident HTTP/WebSocket connection. Pure entity/service validation,
room/display projection and transfer presentation live in `qml-core`; QML retains
the actual Qt objects and pending-request lifecycle.
Use the standard Secret Service API, never a KWallet-specific interface. Tokens
arrive from the setup field through stdin, clear on submit/close, and are stored
only in the system keyring. The mode-0600 `home-assistant.json` stores URL and
preferences. Legacy token files migrate only after a successful keyring save.
Missing configuration keeps the house icon visible and makes no server requests.

Device requests carry explicit intent and remain pending until state confirms
it. Other devices stay usable. Stale values remain visible with controls disabled.
Keep network bounds, redirect rejection, sanitized responses and private fixture
tests. See the submodule's `projects/home-assistant/README.md` for the protocol,
metadata schema and HTTP/WebSocket, store and rendered-panel validation.

## Caffeinate

`seele-caffeinate serve` is a `nerv`-only user service owning one session: the
inhibitor, the task that ends it and the snapshot both surfaces read. It takes a
single systemd-logind `idle` block lock and nothing else. That covers automatic
lock, display-off and idle sleep, because Hypridle honours `BlockInhibited`
while `ignore_systemd_inhibit` stays 0 and logind's `IdleAction` obeys the same
lock. A `sleep` lock would refuse an explicit `systemctl suspend`, so none is
taken; the Wayland per-surface protocol and `org.freedesktop.ScreenSaver` stay
with the windows and applications that own them. Releasing is closing the
descriptor, so exit, logout and a crash all release it, and no other
application's inhibitor is touched.

Modes are until stopped, until an absolute wall-clock deadline, and until a
selected process, recognized build or transfer ends. Every ending is silent and
returns the session to the normal idle policy; nothing locks or suspends as a
completion action. A process is tracked by its start time and pidfd, a transfer
by its group id and terminal state, so PID reuse and the transfer service's own
lifetime cannot extend a session, and an unreadable task ends its session rather
than holding the machine awake. One session exists at a time and a start
replaces it, acquiring the new lock before dropping the old one. Nothing is
persisted.

`projects/qml-core/src/caffeinate.rs` owns duration parsing and bounds, the
labels, the bar text and the failure messages; the shell store and
`seele-control vicinae-caffeinate` read the same projection. The launcher starts
and stops sessions and hands typed durations to native validation verbatim. The
shell contributes only a conditional coffee bar item and a compact panel with
Stop. See `projects/caffeinate/README.md` for the protocol and fixtures.

## Transfers

The Transfers panel filters retained history by filename/device, direction and
outcome using `qml-core` policy. Active jobs remain visible, and explicit
notification focus clears filters before revealing its target. The service
continues to own canonical groups and file indices. See the submodule's
`projects/transfers/README.md` for behavior and the native-backed store and
production Qt panel fixtures.

## Ports

The Control Center's Ports tile opens a local TCP listener inspector on `nerv`.
`seele-ports` in the shell submodule's `tools` crate owns discovery, ownership,
privilege and every action's policy; QML owns the panel, its keyboard behavior
and its confirmations. The worker scans only while the panel is open and keeps
nothing on disk. Its All, Loopback and Network selectors compose with the
existing port/URL/process search. They classify bind addresses; wildcard and
non-loopback bindings are Network, with no inferred firewall or routing state.
Changing filters withdraws a pending review and rejects old query replies.

Discovery reads `/proc/net/tcp` and `/proc/net/tcp6` in the host network
namespace and reports listening sockets only. UDP, remote scanning and other
namespaces are out of scope. A row shows the actual binding, so a wildcard is
never presented as localhost, and it keeps every owner of a shared socket.
Metadata the kernel will not show stays explicitly unknown: another user's
listener is listed without an owner, and an explicit, separately authenticated
Identify owner action is the only way to resolve one. A host-side container
proxy is named as a proxy rather than as the application behind it. Listing
contacts no service and raises no authentication prompt.

Copy address and Open in browser are explicit. Only `http` and `https` are
proposed, the scheme stays visible and changeable because a port proves neither,
and a typed scheme is preserved. A wildcard binding opens the loopback address
of its own family while the row keeps the real binding, and an IPv6 URL stays
bracketed. The URL is built natively; QML never concatenates one.

Stop is always confirmed, and the confirmation names the port, the process or
user, and the exact service. A systemd listener targets its service and
discloses the unit's other listeners, its `Restart=` setting and anything that
can trigger it again; those properties are read only while the plan is built.
Nothing is ever disabled. An unmanaged listener targets the selected process,
and a socket shared by several processes disables Stop until one is chosen.
Force stop is a second confirmation that the backend refuses unless a graceful
attempt on that exact target already left the listener bound; for a service it
stays inside the unit and never falls back to a PID. A system unit or another
user's process goes through `run0` and the packaged `seele-stop-listener`
helper, which takes a typed target rather than a command and revalidates it
after authentication. A cancelled prompt leaves the target running. Identity is
the socket inode plus the process start time, so a vanished listener, a rebound
port or a recycled PID refuses a stale action instead of redirecting it. A
listener still bound afterwards is reported as remaining, never as removed. No
logs are collected or shown. See the submodule's `projects/tools/README.md` for
the protocol, the bounds and the synthetic `/proc` validation.

## Quick Look

Space previews the file a surface has highlighted, without starting the
application that owns it. There is no global Space binding and there never can
be one: the compositor cannot tell a highlighted file from a caret. Only a
surface that can distinguish the two offers the gesture. Yazi does, because
`[mgr]` and `[input]` are separate keymap layers, so the `quicklook` Home
Manager feature takes `<Space>` there and moves Yazi's own selection toggle to
`<C-Space>`, which Ghostty and the configured tmux (`extended-keys on`,
`csi-u`) report apart from NUL. Visual mode and `<C-a>`/`<C-r>` remain the way
to select without it. The feature is separate from `yazi` on purpose: the file
manager is cross-platform and has a portable application, while this binding
needs Seele Shell, so an unmanaged machine keeps Yazi's upstream Space.
Vicinae's own file search owns its action panel and exposes no extension point
for a highlighted item, so Quick Look does not reach it; the Transfers panel,
which the shell owns, offers the same preview for a received file.

`seele-shellctl quicklook <path>...` is the entry point. Relative paths are
resolved against the caller's working directory there, because the shell has
none; the paths travel as one newline-separated argument, since every other
byte is legal in a file name.

The panel is one centered `seele-shell-quicklook` layer surface on the focused
output. It takes exclusive keyboard focus while open and contains no editable
control, which is what lets Space dismiss it exactly as Space opened it. The
surface underneath therefore cannot move to another file while the preview is
up; `←`/`→` (and `h`/`l`) move between the files the caller named, wrapping,
while `↑`/`↓` turn PDF pages, which stop at the document's ends, or scroll a
text body. Enter hands the file to `xdg-open` and closes, `Ctrl + C` copies the
path through stdin, and `P` starts playback, which is never automatic and never
survives a move to the next file.

`seele-quicklook` in the submodule's `tools` crate decides what a path is and
bounds what is read of it; `qml-core`'s `quicklook` owns the header line, the
sizes, the durations and where the keys move. Rendered PDF pages are private
runtime files removed on supersession, cancellation, EOF and SIGTERM. Nothing
redacts content — this is a private reader for the account that already owns
the bytes — but control and direction characters are stripped from names and
text. Keep the panel's namespace in the Hyprland blur rule. See the submodule's
`projects/tools/README.md` for the protocol and
`tests/quicklook.{js,sh}` for its validation.

## Themes

The Control Center's Themes tile and `Super + Ctrl + Shift + T` open the shell's
own theme picker on `nerv`; the Vicinae **Seele Themes** command is the same
catalog from the launcher. `seele-theme` in the submodule's `config-tools` crate
owns the catalog, publication and every reload. `ThemeStore.qml` runs it,
`ThemePanel.qml` draws the preview and the tiles, and `themes.rs` in `qml-core`
owns the catalog's validation, the family grouping, the search and mode filter,
where each arrow key leads, what the preview shows, and every sentence about a
failure or a pending reload.

The store lists only while the panel is open, and it never treats its own
request as the answer: the applied theme comes from the selection file the
helper publishes, watched rather than polled, so a theme applied from the
launcher marks the tile here and a failed switch marks nothing. A palette reaches
a Qt colour property only after the native side has accepted the whole catalog,
so a preset missing a role is refused instead of drawn half-themed. Applying is
single-flight, guarded by a timeout that ends the helper rather than waiting on
it, and the reply is used only to name what has not reloaded yet — never to
claim that the switch failed, because by then it is saved.

The panel leads with a live preview: a small desktop drawn in the highlighted
preset, with the accent on the focused terminal's border because that is what
the switch does to the compositor. It follows the keyboard and the pointer, so
a theme is seen before it is applied, and its caption names the theme it would
replace. Below it each family is a row of tiles, each tile a sample of its
preset. Families come from the whole catalog, so the search and the
All/Dark/Light filter take tiles out without relabelling the rest. Only a
pointer that actually moved chooses a tile: tiles are created and scrolled
under a resting pointer on every keystroke, and treating that as intent would
let a mouse left over the grid take the preview, and Enter, from the keyboard.
Apply keeps the neutral button style, because the selected one falls near 3:1
under light presets with pale accents. The panel keeps nothing on disk,
publishes nothing, and repaints with the rest of the shell as soon as a theme
is applied. Like the Resources and Home Assistant windows, the Themes window
hands its panel the room its output has, and the grid takes what the preview,
the controls and any banner leave. Colour Lab owns the palette mark; Themes carries the light/dark
one. The shell's quiet text depends on the projection's legibility floor in
`seele-theme`, so keep `subtext` and `overlay` derived there rather than read
from Base16 slots directly. See
[the theme switching guide](../../../../docs/theme-switching.md).

## Local controls

- Right-click the clock or use `seele-shellctl control focus` for focus/break
  presets, custom whole-minute durations from 1 to 240, pause/resume and completion.
  The +5 action extends a running or paused timer within the four-hour total;
  an expired timer completes before any extension. `FocusPanel.qml` owns the
  controls and `FocusTimer.qml` retains deadlines only in memory across QML
  reloads; `focus.js` delegates timer policy to Rust. Suspension counts toward
  elapsed time. The offscreen panel fixture exercises the production controls
  through the native policy CLI when Quickshell is unavailable.
- The native notification store owns manual DND, app stacks and verification-code
  copying. Its local associated image is the sender-identity icon, with the
  sending application icon badged over it rather than a second body image. See
  the `seele-shell` skill for the restored 11:00 notification behavior.
- Calendar arrows select days/weeks, Home returns to today, and Enter copies an
  ISO date. World-clock search uses Up/Down and Enter to copy a selected zone;
  Ctrl+Enter copies local time. Timestamps carry explicit UTC offsets.
- Now Playing exposes supported shuffle/repeat modes, keyboard seeking, per-player
  volume and bounded playback-speed presets. Respect each selected player's
  capabilities; live streams never receive seeking writes. Volume writes stay
  within 0–100%, and speed presets use the player's positive minRate/maxRate range.
- Copying network details is an explicit action. Clipboard payloads go through
  process stdin and UI success follows successful process completion.
- The Audio panel's microphone test runs `seele-mic-test` for exactly as long as
  the panel is open. `MicTestStore.qml` holds worker state, `MicTestCard.qml`
  draws it, and `mic_test.rs` in `qml-core` owns device resolution, the derived
  card state and the microphone-use gate. Keep audio lifecycle, routing and level
  measurement in the worker: the meter rests when nothing is being captured,
  clipping comes from the samples rather than from the bar, and a lost device is
  named rather than replaced. Record, Listen live, Replay, Stop and the test
  output rows are focusable buttons and wrap at narrow panel widths.

## Launcher controls

The managed Vicinae Windows command offers native-validated moves to live or
explicitly configured ordinary workspaces. The move keeps the viewed workspace
in place; moving its focused client away lets the compositor select a replacement.
The native endpoint verifies window identity, destination and resulting state.
The existing window list stays available when workspace-rule discovery fails.
See `projects/vicinae/README.md` for the pinned Lua API and process fixtures.

Copy Clean Link reads the clipboard once on explicit invocation, previews a
conservative native HTTP(S) transformation, and copies only on the user's action.
It retains unknown parameters, raw encodings and fragments; recognized signing
or authentication markers keep the original link. It keeps no history and makes
no network requests. The same README owns its stdin/privacy and host-action tests.

## Panel integration

Ordinary panels use `WlrKeyboardFocus.OnDemand`, leaving the bar and click-away
catcher available. Keep their namespaces in the blur rule in
`modules/features/programs/hypr.nix`, including GitHub, Focus, Home Assistant,
Caffeinate, Ports, Quick Look and Themes.
Changing QML alone cannot add compositor blur.

## Validation

`tests/shell-load.sh` compiles the full shell with Quickshell and a private
headless compositor, catching runtime type errors without starting the desktop.
`tests/panel-layouts.js` renders production clock labels, checks the bounded
address disclosure, and exercises focus buttons, keyboard controls and the
notification button's shared hover tint in QtTest. `tests/focus-timer.sh` runs the real
Quickshell timer through cold start, pause/resume and completion without touching
the desktop or sending notifications. `tests/mic-test.js` runs the microphone
test's store against the real native policy, and `tests/mic-test.sh` drives the
worker against a private PipeWire instance with synthetic audio; neither opens
the user's microphone or outputs. `tests/quicklook.js` runs the Quick Look
controller's own functions with fake process, clipboard and compositor IO, and
`tests/quicklook.sh` drives the raw worker against synthetic files and fake
Poppler tools, proving classification, bounds, private page files and cleanup.
`tests/themes.js` runs the theme store's own methods over the native policy and
checks its production wiring, `tests/tst_themes.qml` renders the production
Themes panel in QtTest and fails on any Qt warning, and
`tests/vicinae-themes.cjs` renders the launcher command itself; none of them
applies a theme or touches the session's own state directory.

Run the focused JavaScript suites in `tests/`, the native Rust tests, and the
GitHub/Home Assistant Python fixtures against their raw Rust binaries. The
fixtures live in `projects/runtime/tests/github.py` and
`projects/integrations/tests/home_assistant.py`. They are wired into the shell package and
`test-shell`. Test combined changes as well as independent feature branches,
especially notification panel heights, keyboard focus and asynchronous callbacks.
Use existing local parsers and formatters when available; a successful QML parse
only establishes syntax. Full QML lint with Quickshell types, native builds and
rendering checks still require the normal Nix/Qt workspace. If these tools are
unavailable and installation is forbidden, report that validation boundary; do
not install another Nix or download store closures.

Brave's prelaunch Qt-theme helper is the native `set-brave-qt-theme` in
`projects/desktop-tools`; it skips running/unsafe profiles and publishes private
preferences through pinned descriptors. The existing Nerv Windows reboot service
uses the same crate's `reboot-windows`/`reboot-windows-service` with fixed native
wrappers, root validation and bounded subprocesses. Its Polkit/service authority
is unchanged; tests use temporary profiles and fake firmware commands only.

## Voxtype dictation

`nerv` imports the host-scoped Voxtype Home Manager feature and uses the
flake's x86_64-linux ONNX/CUDA package with an immutable four-file model
directory. `SUPER+D` toggles recording and stopping types the transcript.
Preserve the existing native status/audio socket. The Seele taste skill owns
the language, precision and batch-versus-streaming decision. See
[package, model and validation details](../../../../docs/voxtype-streaming-blocker.md)
before changing the backend.
