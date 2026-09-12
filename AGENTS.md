# Repository guide for coding agents

## Purpose

Seele is a personal, multi-platform dendritic Nix flake for one user (`silash`). It defines:

- NixOS host `nerv` (`x86_64-linux`)
- nix-darwin host `asuka` (`aarch64-darwin`)
- Home Manager profiles shared by both hosts and specialized by platform/host
- local packages (`codexbar`, `nixvim`, `pipewire-nothing`, `shell-ai`, `spt-st`, `t3code-nightly`), the `seele-shell` and `seele-notes` submodule packages, and overlays

Use the `seele` skill in `.agents/skills/` for the workflow and architecture map. Use `seele-shell` for changes inside the shell submodule, for the shell's design tokens and shared QML components, and for its rebuild-ready commit, push, gitlink, and transitive input lock flow. Use `seele-taste` when choosing tools, UI defaults, keybindings, automation, privacy settings, or cross-platform equivalents that the request leaves open.

## Before editing

- Run `jj status` and preserve all pre-existing changes. Use Jujutsu for all change tracking and history operations; do not use Git's staging area.
- Every `.nix` file under `modules/` is recursively imported by `import-tree`, except paths containing `/_`. A leaf must be a flake-parts module, not a bare NixOS, nix-darwin, or Home Manager module.
- Determine whether a change contributes to a named module, an active `common`/platform/host profile, or only a package/flake output. Keep the narrowest correct scope.
- Do not expose credentials, SSH material, machine identifiers, or local agent/auth configuration.

## Architecture

- `flake.nix`: inputs and the `flake-parts`/`import-tree` bootstrap.
- `modules/flake/`: repository options, systems, package-set policy, overlays, the formatter, the portable-application builder, and repository helper apps.
- `modules/features/`: program, service, theme, and system leaves. Each leaf publishes deferred modules through `flake.modules.<class>.<name>`.
- `modules/profiles/home/`: shared, OS-specific, and host-specific Home Manager profiles. These import named feature modules in activation order.
- `modules/hosts/{nerv,asuka}.nix`: host output constructors and Home Manager integration.
- `modules/hosts/{nerv,asuka}/`: machine-specific deferred modules, including hardware configuration.
- `modules/packages/`: `perSystem` package outputs. Underscore-prefixed directories contain raw package assets/configuration and are excluded from recursive module imports.

Active profiles are `common`, `linux`/`darwin`, and `nerv`/`asuka`. Host constructors compose the matching profiles. Named feature modules remain dormant until a profile imports them.

`modules/flake/core.nix` owns per-host `seele.hosts.<name>.username` values, `seele.catppuccin`, supported systems, unstable `pkgs`, and OS-matched `pkgs-stable`. Host constructors pass `username`, `currentSystem`, `selfPackages`, `pkgs-stable`, `catppuccin`, and `configName` to Home Manager. Reuse these arguments instead of re-importing nixpkgs or hard-coding store paths.

Both hosts run Determinate Nix. `modules/features/system/determinate.nix` publishes `flake.modules.nixos.determinate` and `flake.modules.darwin.determinate` around the `determinate` input's modules, and the NixOS and Darwin `common` profiles import them. How Nix is configured then differs by platform. The NixOS module keeps `nix.settings` and `nix.registry` working by redirecting the generated `/etc/nix/nix.conf` to `/etc/nix/nix.custom.conf`. The nix-darwin module forces `nix.enable` off, so a Darwin leaf that configures Nix writes `determinateNix.customSettings` and `determinateNix.registry` instead; anything left in `nix.settings` there is silently dropped. Keep the `determinate` input free of a nixpkgs `follows`. On `asuka`, Determinate Nix itself comes from Determinate's macOS installer, because the nix-darwin module only configures an existing installation. `flake.modules.homeManager.determinate` covers every machine rather than only the two hosts: the Home Manager `common` profile imports it, and the portable builder adds it to every standalone evaluation. It forces `nix.package = null` because Home Manager's NixOS integration otherwise supplies its own package, ensuring no user profile carries a second Nix onto a managed or unmanaged machine.

The `middle-click` Home Manager feature on `nerv` disables primary-selection
paste in GTK 3/4 widgets and enables Zen's native autoscroll with primary paste
and selection-URL loading disabled. This is partial SIL-49 support: it does not
provide global input interception, a shared indicator, or autoscroll for Seele,
Qt, or terminals. See the Seele skill's `middle-click.md` reference for the
remaining platform boundary and validation matrix.

Remote shell access on `nerv` is one exclusive Seele Shell selector: `off` disables both incoming paths, `tailscale` enables Tailscale SSH and stops OpenSSH, and `ssh` disables Tailscale SSH and starts ordinary OpenSSH. OpenSSH never starts automatically, accepts public keys only, and uses the normal port 22 firewall opening while selected.

On `nerv`, `seele-codex call` and `seele-codex request` reach the private,
socket-activated Codex broker. It owns model selection, schema validation,
concurrency, retries, cancellation and supersession. Integrations retain their
own durable source data; broker payloads and results are memory-only. The AI
panel Activity tab reads metadata only, preserves actual queue order, and offers
cancel, retry, do-next, and dismiss. Failures stay until resolved; other terminal
states disappear after five seconds. Activity never creates notifications. See
`seele-shell/projects/broker/README.md` for the versioned protocol and the
local fake-model check proving the Codex request exposes no tools.

Fish command assistance on Linux comes from `packages.x86_64-linux.shell-ai` and the active `shell-ai` Home Manager feature. One Enter binding treats leading `how` and `debug` command lines as generation modes, then replaces the prompt for review without executing it; every other line reaches the normal Fish execute action. Both modes use the same bounded context collector and insertion path. A private per-session Rust stderr wrapper retains only the last failed foreground command in memory; a same-user Unix socket exposes it to `debug`, which sends its redacted command, status and stderr to the shared Codex broker only when requested. Destructive suggestions are inserted as comments that require deliberate uncommenting.

The native Hyprland screenshot helper freezes the displayed frame and uses one picker
for window, monitor, and region captures. Every completed capture receives an
atomically published timestamped path under `Pictures/Screenshots` and is copied
after optional Satty annotation. `Super + Alt + S` adds an explicit native
consent dialog before a 24-hour secret-link upload to the public third-party
host 0x0.st; declining or any upload failure keeps and copies the local image.

On `nerv`, `Super + Ctrl + S` invokes `seele-shellctl uris`. The shell freezes
one image per output and globally numbers exact text from normal panes in the
focused Ghostty/tmux client before OCR-detected URIs, QR codes, and barcodes.
Exact terminal URLs and canonical existing paths open; Jujutsu revision IDs and
non-URI code payloads copy. Ctrl + number copies any selection. Unsupported or
ambiguous terminal geometry falls back to OCR, while GUI OCR and whole-output
code scanning remain active. Code captions show decoded text below the code, or
above when space is short. The submodule owns the QML overlay, tmux/Hyprland
identity checks, and resident Rust recognition worker; the parent owns the
Hyprland binding. Keep capture and recognition dependencies in official
nixpkgs. Captures are private runtime files, never screenshot-library or
persistent-cache entries.

On `nerv`, `Super + Space` invokes `seele-shellctl prompt`. The shell maps a
centered prompt on the focused output immediately through a resident Rust
controller, but starts Codex only after Send. `@window` exposes only the
captured application name and title, and `@dir` resolves only a focused
terminal through `/proc`. Explicit `@clip`, `@select`, `@dir`, and `@screen` mentions resolve only on Send,
then submit together after all sources succeed. Screen collection hides the panel
and captures only its pinned output. A failed source preserves the prompt;
edits or closing invalidate the collection. Model-requested context still needs
one-time approval, and screen context needs Capture and preview confirmation. Each model turn uses the shared
no-tools Codex isolation policy and a private empty runtime workspace; follow-ups
resume one session only while the panel remains open. Escape or shutdown terminates any
turn, deletes its Codex session, and removes private captures. Enter sends or
copies according to input state; Ctrl + Enter restores the validated original
Hyprland window and inserts the answer without moving the pointer.

Seele Shell owns `org.freedesktop.Notifications` through Quickshell's native
notification server; mako stays disabled. The shell handles actions, resident
and transient lifetimes, a 30-second default toast timeout, permanent/pinned
toasts, app stacks, local images, progress, and verification-code copying. A
local notification image leads its card as the rounded sender identity, while
the sending application's icon moves to a lower-right badge instead of the
image being repeated in the body. Do Not Disturb is both a switch and a timed
quiet period of 15 minutes, 1 hour, or 4 hours. Notification state and DND
belong to a resident Rust policy object owned by Qt; the QML store holds native
notification objects and delivers callbacks. The hardware feed is independent. History,
pins, and a running quiet period survive QML reloads in memory; notification
text is never written to disk. See the `seele-shell` skill for the protocol
and tests.

On `nerv`, `modules/features/system/failure-analysis.nix` attaches an
`OnFailure=` reporter to installed system services with a systemd generator.
It reads only the failed invocation's journal, adds local `nix --offline log`
output for derivations named there, and adds kernel warnings only inside that
invocation's time window when its messages point at the kernel. Reports cross
from root to the desktop user over stdin and stay mode `0600` below the private
runtime directory. The Seele notification offers local viewing in a centered
Neovim scratch buffer or explicit AI analysis; doing nothing sends nothing.
Only the AI action passes a redacted report to a shared no-tools Codex broker over
its private socket. The `rebuild` Fish abbreviation and Seele OS session use
`seele-rebuild`, which forwards progress bytes unchanged and retains a bounded
failure tail for the same consent path. `systemctl start seele-failure-test` deliberately exercises it.

Seele Notes is a separate desktop app from the shell submodule's `notes`
package, exposed as `packages.<system>.seele-notes` and installed on Linux by
its own `flake.modules.homeManager.seele-notes` feature. It is a quick-capture
front end for an Obsidian vault, not a second library: notes are ordinary
Markdown files in one configured folder of that vault, and Obsidian owns
everything else. `modules/features/programs/seele-notes.nix` declares the
optional `seele.notes.{vault,directory,attachments}` options and writes them to
`seele-notes/config.json` only when a vault is named; the app's own directory
picker writes the user's choice to its private settings file, and that choice
wins. Recordings are vault files in an attachment folder referenced by Obsidian
embeds, so removing an embed never deletes audio another note may reference.
Trash moves a note into the vault's `.trash`, keeping the restore path in
private state. Never write Seele's own state into the vault. It shares
`projects/shared/Theme.qml` and the same QML components with Seele Shell.
Dictation uses Voxtype's native status and audio socket, with a
non-interactive bottom waveform on the output where recording began. See the
`seele-shell` skill for the protocol, the editor, and validation.

Vicinae's managed extension lives in `seele-shell/projects/vicinae/`. It exposes
live controls, audio device selection, window/workspace search, keybindings,
NixOS generation rollback, and direct shell commands. For extension changes,
read its `README.md`; the shell package bundles the manifest's command entries
and runs its focused checks. Home Manager installs it through `xdg.dataFile`.
The generation picker identifies the running closure by resolving
`/run/current-system`, shows an `nvd` diff before offering a switch, and
revalidates the reviewed generation immediately before escalation. Its packaged
root helper accepts a positive generation number and the two reviewed store
basenames, rechecks their canonical identities after authentication, advances the
system profile with the running system's `nix-env`, and activates the exact
resolved closure through the running system's `run0`. Failed or stale diffs never
enable switching. Native `seele-control vicinae-*` endpoints own snapshots,
keybinding policy/input, audio revalidation and immutable diff formatting; React
retains rendering, confirmation, locale collation and host callbacks. Keep garbage collection out of the
picker; `nh` remains the sole owner of generation retention. The shell Audio
panel and Vicinae share `seele-control audio-outputs` for simultaneous playback;
`projects/tools/src/audio_route.rs` owns the session-local PipeWire combined
sink and its cleanup. Test routing on the private server in
`seele-shell/tests/audio-routing.sh`.

On `nerv`, the `seele-transfers` user service automatically receives Taildrop
files into the configured XDG Downloads folder with exclusive numbered names
and user-owned mode-0600 files. The shell owns the Transfers panel, Control
Center module, conditional progress bar item, and provider-neutral contract.
The service selects only currently available targets owned by the logged-in
Tailscale user. It retains seven days of metadata, never file contents; clearing
history never deletes files. `asuka` has no transfer service. See the submodule's
`projects/transfers/README.md` for protocol, tests and Taildrop's incoming
identity/cancellation limitations.

Home Assistant's house icon stays visible before setup. Its panel stores the token
through the standard Secret Service interface and keeps only connection metadata
and display preferences in its private JSON file. See the Seele skill's
`shell-integrations.md` reference for live state, per-device confirmation,
room/favorite organization and fixture validation.

Portable applications are the second way a feature reaches outside this flake. `modules/flake/portable.nix` declares `seele.portable.<app>`, and each program leaf worth running on an unmanaged machine contributes one entry beside its `flake.modules.homeManager` definition. An entry names the Home Manager features to evaluate, and the builder wraps the resulting binary so it materializes the generated `.config` tree as a symlink farm below `$XDG_CACHE_HOME/seele/portable/<app>` and puts that evaluation's own `home.path` on `PATH`. The evaluation is standalone rather than host-derived, so a feature the app reads through has to be listed or its options resolve to Home Manager defaults instead of the values a host would give them.

Portable and Glow launchers use the native `seele-launch` manifest contract.
Session values are data substitutions (`$NAME`, `${NAME:-default}` and related
unset/alternate forms), with bounded nesting and no shell command evaluation.
The same process materializes owned config links and then execs the application;
compiled wrappers pin its manifest. Home Manager numbered backups use
`seele-home-backup` with the packaged native `mv` and an exact destination, so
an existing backup directory cannot redirect the operation. All launch declarations
validate before configuration publication. See
`seele-shell/projects/config-tools/README.md` before changing these boundaries.

Theme ownership is split deliberately. Catppuccin themes supported application ports and supplies the Papirus icon theme. Stylix owns Qt and GTK widget themes, fonts, and active targets without a Catppuccin module. Qt's qt5ct and qt6ct settings reuse the Catppuccin Papirus icon theme. `stylix.autoEnable` stays off, and each platform profile lists its active Stylix targets explicitly so dormant applications do not add configuration or packages. Seele QML clients receive the selected palette through generated `theme.json`; `seele-shell/projects/shared/Palette.js` is their single unmanaged fallback and shared assignment path.

## Native runtime ownership

First-party services and command helpers live in the single Rust workspace under
`seele-shell/projects/`: `runtime`, `tools`, `broker`, `maintenance`, `prompt`,
`integrations`, `failure-analysis`, `shell-ai`, `config-tools`, `desktop-tools`
and `repo-tools`, with shared UI policy in `qml-core` and editor formatting in
`markdown-core`. The workspace owns one lock file and release policy;
`seele-shell/packages/core/native.nix` owns their common build policy. Parent
package leaves re-export Linux services or use `inputs.seele-shell.lib.mkNativePackage`
for portable helpers. Native wrappers add required executable paths at feature
boundaries; repository helpers reuse the caller's Nix distribution.

Use `seele-runtime` for bounded processes, cancellation, peer-verified framed
sockets, private atomic files, timestamps, redaction and broker inference. Share
policy there instead of copying loops across consumers. Keep diagnostics out of
model argv and preserve consent and memory-only payload ownership.

Shared Codex contexts have empty private HOME/CODEX_HOME directories and delegate
only the validated existing file authentication store, preserving refresh writes.
They never inherit user instructions/configuration/plugins; keyring-only auth
fails with an actionable diagnostic. Broker configuration owns model selection
for prompt turns too. Keep synthetic first/resume/image wire fixtures proving
an empty tool list and absent hostile home instructions; never use real auth in tests.

`qml-core` owns pure QML policy, numeric/date/editor compatibility and resident
notification state. The small Qt bridge preserves real JavaScript arrays and
object keys through the engine's captured JSON parser; replacing that return
boundary with QVariant conversion breaks array/list contracts. QML retains Qt
objects, signals, material geometry, transparency and animations. Thin JavaScript
adapters handle those host objects, Date/locale conversion and model operations.

Pi footer formatting, sanitization and layout planning also use `qml-core`,
through the stable `projects/node` Node-API bridge and `packages.<system>.node-core`.
Its TypeScript adapter owns Pi callbacks, terminal measurement/truncation and
theme painting, with no render-time subprocess. `seele-pi-jj` bounds lifecycle
metadata reads. Vicinae keeps React, clipboard/confirmation and locale APIs,
plus scalar icon/text expressions in the rendered controls. Those expressions
start no subprocesses, retain no policy state and make no security decisions.
Spicetify's accent adapter requires browser localStorage. Upstream applications
such as Proton VPN retain their own runtimes. Python/Node fixture tools remain
build/test dependencies of native services, with no first-party Python workers.
Pi/OpenCode lifecycle adapters call the shared native `seele-agent-hook`; they
never write state files themselves. Native lock/greeter/Notes launchers live in
`projects/tools/src/launch.rs`. A detached lock must survive launcher completion
and confirmation failure; run the synthetic launcher fixtures after changing
subprocess ownership. Never exercise these tests against a real desktop.
Do not expand these API exceptions into new runtime scripting. See the Pi and
Proton adapter READMEs for their exact boundaries.

Parent security configuration findings, upstream evidence and remaining native-host validation are recorded in [the configuration audit](docs/security-configuration-audit.md). Read it before changing authentication, Bluetooth pairing, input privileges, suspend locking or sensitive-service crash handling.

## Editing conventions

- Follow nearby leaf style and let the flake formatter decide layout.
- Put reusable feature behavior in a descriptive named module under `modules/features/`.
- Import named user features from the matching `modules/profiles/home/` profile and named system features from the matching system or host aggregate; preserve import order.
- Keep dormant feature modules out of active profile imports.
- Contribute system-only behavior to the matching NixOS or Darwin `common`, OS, or host profile.
- Put reusable derivations under `modules/packages/` and package-set overrides in `modules/flake/overlays.nix`.
- Publish a configured program for unmanaged machines by adding `seele.portable.<command>` to its own feature leaf, named after the command it runs rather than the feature. List every feature it reads through, and narrow `systems` when the program is platform-bound.
- Consume standalone package repositories through flake inputs; keep their output wiring in `modules/packages/`. The `seele-shell` submodule is a declarative path input included through `inputs.self.submodules`; its gitlink pins the shell, Notes, greeter, lock, and polkit package sources.
- Pin binary packages whose releases are consumed directly (`codexbar` and `t3code-nightly`) with literal versions and hashes in their package leaves. Run `nix run .#update-packaged` to refresh both pins from their public release APIs; the helper also prefetches CodexBar to record its Nix hash.
- Keep raw Nix expressions that are not flake-parts modules below a path containing `/_` so `import-tree` ignores them.
- Prefer explicit package references in generated shell snippets when execution must not depend on `PATH`.
- Preserve state versions, hardware UUIDs, usernames, and signing keys unless explicitly requested.
- Update `flake.lock` only when the task changes inputs.
- Follow the `seele-shell` skill when committing and pushing the submodule and updating its parent gitlink. The path input follows that gitlink, so shell source-only revisions do not change `flake.lock`; the helper still refreshes the shell's transitive input locks.
- Use `jj file track <path>` if a new file is not tracked automatically. Use Jujutsu equivalents for restore/history operations.

## Keep agent guidance current

After every repository change, review `AGENTS.md` and `.agents/skills/seele/` against the resulting codebase. When a change establishes or reverses a configuration preference, also review `.agents/skills/seele-taste/`. Update guidance when architecture, profiles, outputs, commands, validation, conventions, workflows, or preferences changed.

## Validation

Always format the entire repository:

```sh
nix fmt
```

For intentional CodexBar and T3 Code release updates, refresh their pins with:

```sh
nix run .#update-packaged
```

Then inspect `jj diff` and run:

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.nerv.config.system.build.toplevel.drvPath --no-write-lock-file # Linux
nix eval --raw .#darwinConfigurations.asuka.system.drvPath --no-write-lock-file                   # Darwin
```

For relevant build validation, plain `nix build` builds the current native host closure:

```sh
nix build --no-link --no-write-lock-file
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#packages.${system}.nixvim" --no-link --no-write-lock-file
nix build ".#packages.${system}.<portable-app>" --no-link --no-write-lock-file
nix build .#nixosConfigurations.nerv.config.system.build.toplevel --no-link --no-write-lock-file # Linux
nix build .#darwinConfigurations.asuka.system --no-link --no-write-lock-file                     # Darwin
```

Validate `asuka` on Darwin and `nerv` on Linux. Complete Darwin evaluation on Linux can try to realize Darwin-only Catppuccin assets and fail with a platform mismatch; report that boundary.

Activation changes the live machine. Run `nh os switch`, `nh darwin switch`, `nixos-rebuild`, or `darwin-rebuild` only when the user explicitly requests activation.

Known baseline warnings include the nixvim/nixpkgs `follows` warning and upstream option/deprecation warnings. Compare with the baseline before attributing warnings to a change.

Integration Health is a Control Center module and a conditional bar warning,
with no health notifications or transition history. Integration owners explicitly
register through `seele.health.providers`; disabling a registration removes it.
Existing GitHub, Home Assistant and Tailscale source callbacks publish bounded
semantic metadata, and `IntegrationHealthStore` derives stale state centrally.
External configured providers publish through the `health` IPC target. See
`seele-shell/projects/shell/HEALTH.md` for the versioned contract and typed actions.

System Health combines Integration Health and Maintenance. The maintenance user
service owns persistent sanitized finding metadata and seven-day resolved history;
diagnostic bundles and AI results stay only in memory. Publishers deduplicate by
source/key and alone resolve ongoing conditions. Snooze escalation, typed actions
and explicit repair confirmation are enforced by the service as well as the UI.
AI analysis is explicit and goes through the shared Codex broker, with repair IDs
restricted to the finding's registered actions. It never executes a proposal.
See `seele-shell/projects/maintenance/README.md` for source policy and validation.
