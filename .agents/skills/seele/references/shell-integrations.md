# Seele Shell integrations and controls

Shell features remain in the `seele-shell` source repository; the parent consumes
its published revision through the existing gitlink/path input. Source-only
changes do not change `flake.lock` when the shell's inputs and lock are unchanged.

## GitHub

`seele-shellctl control github` opens requested reviews and authored open pull
requests, with CI rollups and review decisions. `projects/runtime/src/github.rs` uses
the existing `gh` login and projects bounded, read-only API responses.
`GitHubStore.qml` owns Qt request lifecycle and in-memory snapshots; `github.js`
forwards pure snapshot/refresh/label policy to `projects/qml-core/src/github.rs`.
The UI and native collector share `seele_runtime::github::safe_url`.
Keep credentials out of QML, logs, command arguments and the store; never initiate
login from the panel. Results refresh only while open. Use fixture/fake-gh tests,
not a real account, when validating request logic. See the submodule's
`projects/github/README.md` for optional enterprise-host setup and keyboard keys.

## Home Assistant

`seele-shellctl control home-assistant` opens the always-visible house entry's
panel. `HomeAssistantPanel.qml` owns setup, selected devices, room groups,
favorites, light sliders, fan power/speed and the optional menu bar reading.
Temperature and humidity appear only in their room header, including unavailable
readings; keep them selectable in the device picker. Preserve list identity
across live updates so an active field or slider keeps its delegate.

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

## Local controls

- Right-click the clock or use `seele-shellctl control focus` for focus/break
  presets, pause/resume and completion. `FocusTimer.qml` retains deadlines only in
  memory across QML reloads; `focus.js` delegates timer policy to Rust. Suspension
  counts toward elapsed time.
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

## Panel integration

Ordinary panels use `WlrKeyboardFocus.OnDemand`, leaving the bar and click-away
catcher available. Keep their namespaces in the blur rule in
`modules/features/programs/hypr.nix`, including GitHub, Focus and Home Assistant.
Changing QML alone cannot add compositor blur.

## Validation

`tests/shell-load.sh` compiles the full shell with Quickshell and a private
headless compositor, catching runtime type errors without starting the desktop.
`tests/panel-layouts.js` renders production clock labels, checks the bounded
address disclosure, and exercises focus buttons, keyboard controls and the
notification button's shared hover tint in QtTest. `tests/focus-timer.sh` runs the real
Quickshell timer through cold start, pause/resume and completion without touching
the desktop or sending notifications.

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
