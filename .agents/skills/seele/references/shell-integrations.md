# Seele Shell integrations and controls

Shell features remain in the `seele-shell` source repository; the parent consumes
its published revision through the existing gitlink/path input. Source-only
changes do not change `flake.lock` when the shell's inputs and lock are unchanged.

## GitHub

`seele-shellctl control github` opens requested reviews and authored open pull
requests, with CI rollups and review decisions. `projects/github/status.py` uses
the existing `gh` login and projects bounded, read-only API responses.
`GitHubStore.qml` and `github.js` own request lifecycle and in-memory snapshots.
Keep credentials out of QML, logs, command arguments and the store; never initiate
login from the panel. Results refresh only while open. Use fixture/fake-gh tests,
not a real account, when validating request logic. See the submodule's
`projects/github/README.md` for optional enterprise-host setup and keyboard keys.

## Home Assistant

`seele-shellctl control home-assistant` opens selected entity states and explicit
light/switch/input_boolean on/off controls. Other selected domains are read-only.
`projects/home-assistant/control.py` alone reads the private user-owned mode-0600
regular connection file at `$XDG_CONFIG_HOME/seele-shell/home-assistant.json`.
`SEELE_HOME_ASSISTANT_CONFIG` can override the path. Do not generate this token
through Nix. Missing configuration disables network access and hides the bar item.
Keep requests bounded, do not forward authorization across redirects, and disable
controls when state is stale. Mock-HTTP tests never load the user's connection.
The submodule's `projects/home-assistant/README.md` documents the JSON schema.

## Local controls

- Right-click the clock or use `seele-shellctl control focus` for focus/break
  presets, pause/resume and completion. `FocusTimer.qml`/`focus.js` retain deadlines
  only in memory across QML reloads; suspension counts toward elapsed time.
- The native notification store owns timed DND, search and text copying. Timed
  quiet periods expire without replaying the backlog. Manual DND replaces a timer.
  Search and copying do not dismiss entries or persist message text.
- Calendar arrows select days/weeks, Home returns to today, and Enter copies an
  ISO date. World-clock search uses Up/Down and Enter to copy a selected zone;
  Ctrl+Enter copies local time. Timestamps carry explicit UTC offsets.
- Now Playing exposes supported shuffle/repeat modes, keyboard seeking, per-player
  volume and bounded playback-speed presets. Respect each selected player's
  capabilities; live streams never receive seeking writes. Volume writes stay
  within 0–100%, and speed presets use the player's positive minRate/maxRate range.
- Copying network details is an explicit action. Clipboard payloads go through
  process stdin and UI success follows successful process completion.

## Validation

Run the focused JavaScript suites in `tests/` and the GitHub/Home Assistant Python
suites with private fixtures. They are wired into the shell package and
`test-shell`. Test combined changes as well as independent feature branches,
especially notification panel heights, keyboard focus and asynchronous callbacks.
Use existing local parsers and formatters when available; a successful QML parse
only establishes syntax. Full QML lint with Quickshell types, native builds and
rendering checks still require the normal Nix/Qt workspace. If these tools are
unavailable and installation is forbidden, report that validation boundary; do
not install another Nix or download store closures.
