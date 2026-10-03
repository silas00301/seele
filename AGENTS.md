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

The `theme-switching` Home Manager feature on `nerv` provides **Seele Themes**
in Vicinae, the shell's floating theme switcher, the Control Center's Themes
panel, and `Super + Ctrl + Shift + T`, which toggles the switcher without
closing any open panel. The desktop keeps a light theme and a dark theme and a
mode that picks between them. The switcher is every preset, never filtered:
moving switches the desktop at once, so the shell repainting around it is the
preview, a preset chosen there becomes the theme for its own mode and brings
that mode with it, and Escape puts the mode and both themes back. The Themes
tile's knob shows Light, Dark or Auto and steps to the next; the tile opens the
panel, which holds that choice, the schedule's source and times, and a Use
current button that gives the preset on screen to either mode. Auto follows a
schedule at fixed times or at sunrise and sunset; the `seele-theme-auto` user
service runs the native helper's edge-triggered loop, so a mode chosen by hand
holds until the next boundary. While a `nix build` or `nix-build` process is
running, that scheduled step waits and applies on a later pass; a foreground
Fish `nix build` notifies once when its terminal window is unfocused. Sunrise
and sunset are reckoned from the system
timezone's reference city in the tz database; no location is asked for or
stored. The native `seele-theme` helper owns the slots, the mode, the schedule
and publication, and every surface only runs it; the shell reads the applied
theme and the preferences from the files the helper publishes, so a change from
anywhere is seen there. Ordering, movement and the schedule's sentence belong to
`qml-core`. The projection holds the shell's quiet text to a legibility floor
rather than reading Base16's dim slots verbatim, because Catppuccin's Base16
file puts surface colours there. Vesktop reloads the helper's in-place QuickCSS
update; Neovim selects the official colorscheme for Catppuccin presets and
Stylix's Base16 palette for the others. See [the theme switching guide](docs/theme-switching.md)
for scope, ownership and application reload boundaries.

## Architecture

Every first-party Qt UI shares Vim-shaped keyboard navigation through
`seele-shell/projects/navigation/` and the shared QML components. The
[navigation guide](seele-shell/projects/navigation/README.md) owns its bindings
and validation; `Super + Ctrl + B` enters the bar on `nerv`. Preserve text entry,
field-level cancellation, and the existing UI material when adding controls.

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

`modules/features/system/foreign-binaries.nix` publishes
`flake.modules.nixos.foreign-binaries`, which the NixOS `linux` profile imports,
so prebuilt Linux software runs on `nerv` without patchelf or a hand-built FHS
environment. nix-ld supplies the loader and library path a foreign binary
expects; its library list is defined in upstream's `config`, so a definition
here merges with the systemd and Nix libraries nixpkgs already lists rather than
replacing them, and graphical toolkits stay out of it. `programs.appimage` with
binfmt registration makes an executable AppImage run directly. Neither replaces
packaging: an AppImage worth keeping still gets a package leaf, as
`t3code-nightly` has.

`modules/features/system/disk-health.nix` publishes
`flake.modules.nixos.disk-health`, which the NixOS `linux` profile imports, so
SMART monitoring reaches every NixOS host rather than one machine. smartd
autodetects devices instead of listing them, adds a nightly short and weekly
long self-test to upstream's `-a`, and reports through systembus-notify, which
forwards a root service's system-bus message into Seele Shell's notification
server. Upstream derives `-M exec` from the mail, wall and X11 toggles only, so
`wall` stays enabled deliberately; X11 notifications are off because this host
enables `services.xserver` for its keymap but runs a Wayland session.
`systemctl start seele-disk-health-test` sends the same message without failing
hardware, and smartd's own failure is covered by the failure-analysis reporter.

The `middle-click` Home Manager feature on `nerv` disables primary-selection
paste in GTK 3/4 widgets and enables Zen's native autoscroll with primary paste
and selection-URL loading disabled. This is partial SIL-49 support: it does not
provide global input interception, a shared indicator, or autoscroll for Seele,
Qt, or terminals. See the Seele skill's `middle-click.md` reference for the
remaining platform boundary and validation matrix.

The `removable-media` feature mounts external disks on `nerv`. Its NixOS half
enables udisks2 explicitly rather than relying on the fallback Plasma session
that pulls it in, and adds the exFAT and NTFS drivers that foreign-formatted
sticks need. Its Home Manager half runs udiskie in the Hyprland session with
automounting and notifications on and no tray of its own, because Seele Shell
already owns the bar and the notification server; udiskie's Browse action opens
Yazi in Ghostty. `Super + Shift + E` unmounts and powers off every attached
removable device at once and notifies only when one is still in use, since the
daemon already reports each successful release.

Remote shell access on `nerv` is one exclusive Seele Shell selector: `off` disables both incoming paths, `tailscale` enables Tailscale SSH and stops OpenSSH, and `ssh` disables Tailscale SSH and starts ordinary OpenSSH. OpenSSH never starts automatically, accepts public keys only, and uses the normal port 22 firewall opening while selected.

Containers on `nerv` are rootless Podman only. `modules/features/system/containers.nix`
publishes `flake.modules.nixos.podman` and a matching `homeManager.podman`; the
`nerv` system aggregate and the `nerv` home profile import them, and `asuka`
gets nothing, because containers on aarch64-darwin need a `podman machine`
Linux VM with its own lifecycle. Nothing here creates a privileged daemon or a
root-equivalent group: `dockerCompat` and `dockerSocket` stay off, and the
rootful API socket is removed from `sockets.target` while the per-user socket
remains. Compose works through an external provider on podman's own wrapper
PATH rather than a `docker` command on the user's PATH. NixOS already allocates
the subordinate UID/GID range for a normal user, and the default network is left
alone because that option only reaches the rootful configuration directory.
Pruning is a weekly user timer bounded to resources untouched for seven days,
never volumes and never `--all`; `nh` still owns Nix generation retention.

DNS on `nerv` is a local caching `systemd-resolved` stub resolving through
Quad9 over strict DNS-over-TLS, with each address pinned to `dns.quad9.net` so
the certificate is actually authenticated. A global `~.` routing domain keeps
those encrypted servers ahead of the DHCP resolver, while longer per-link
domains still win, so Tailscale MagicDNS and the lease's own search and reverse
zones keep resolving. Local DNSSEC validation stays off because Quad9 validates
and the transport is already authenticated; LLMNR is off and mDNS resolves
without responding. NetworkManager hands every link to resolved and defaults
each profile to per-link DNS-over-TLS off, LLMNR off, and mDNS resolve-only. A
captive portal breaks resolution rather than redirecting it, which
`modules/hosts/nerv/dns.nix` accepts and answers with a temporary `resolvectl`
escape.

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
controller, but starts Codex only after Send. The panel takes exclusive
keyboard focus while it is open, so typing reaches its field immediately and
only Super + Space, Close or Escape gives the keyboard back. `@window` exposes only the
captured application name and title, and `@dir` resolves only a focused
terminal through `/proc`. Typing `@` opens a completion list of those sources and inserts the chosen mention without reading it. Explicit `@clip`, `@select`, `@dir`, and `@screen` mentions resolve only on Send,
then submit together after all sources succeed. Screen collection hides the panel
and captures only its pinned output. A failed source preserves the prompt;
edits or closing invalidate the collection. Model-requested context still needs
one-time approval, and screen context needs Capture and preview confirmation. Each model turn uses the shared
no-tools Codex isolation policy and a private empty runtime workspace; follow-ups
resume one session only while the panel remains open. Escape or shutdown terminates any
turn, deletes its Codex session, and removes private captures. Enter sends or
copies according to input state; Ctrl + Enter restores the validated original
Hyprland window and inserts the answer without moving the pointer.

On `nerv`, Space previews the file a surface has highlighted without starting
the application that owns it. There is no global Space binding and there cannot
be one: only a surface that can tell a highlighted file from a caret may offer
the gesture. The `quicklook` Home Manager feature takes `<Space>` in Yazi's
`[mgr]` layer, which is separate from its `[input]` layer, and moves Yazi's own
selection toggle to `<C-Space>`; it is a feature of its own rather than part of
`yazi`, because the file manager is cross-platform and portable while the
binding needs Seele Shell. `seele-shellctl quicklook <path>...` is the entry
point, and the Transfers panel offers the same preview for a received file.
Vicinae's built-in file search owns its own action panel and is out of reach.
The panel is one centered layer surface that holds the keyboard while open and
contains no editable control, so Space dismisses it exactly as Space opened it;
arrows move between the named files and through PDF pages, Enter hands the file
to its application, and playback is always explicit. The resident
`seele-quicklook` worker classifies a path from its container magic, bounds
what it reads, and drives Poppler into a private runtime directory removed on
supersession, cancellation, EOF and termination. Nothing redacts content — this
is a private reader for the account that already owns the bytes — but the
control and direction characters that could forge a line of interface are
stripped. See the Seele skill's `shell-integrations.md` and the submodule's
`projects/tools/README.md`.

On `nerv`, `Super + GRAVE` toggles a scratchpad terminal on Hyprland's
`special:scratchpad` workspace. The `scratchpad` Home Manager feature owns the
workspace rule, the window rule and the binding; the compositor spawns one
Ghostty of its own class through `on_created_empty`, so the first summon and the
one after the window was closed take the same path and nothing tracks whether it
already runs. Its tmux session outlives the window, and the window floats
centered rather than anchored to the top edge, because a window rule cannot see
the space the shell's bar reserves. Ghostty's native quick terminal stays the
macOS implementation of the same gesture: its `+toggle-quick-terminal` IPC
action needs Ghostty 1.4.0 and this flake pins 1.3.1.

Fish reports a command that ran for more than ten seconds and finished while
its terminal window was not focused. The `command-notifications` Home Manager
feature in the `common` profile loads the `done` plugin, which times commands,
compares the focused window at start and end, and stays silent over SSH. On
`nerv`, `command-notifications-seele` replaces the plugin's own notify-send call:
the shell never lists a transient notification in its panel and withdraws it when
its toast retires, which the plugin sets to three seconds, and the plugin raises
failures as critical, which the shell keeps on screen until dismissed. The hook sends an ordinary notification whose Show action
focuses the originating Ghostty window through `seele-control vicinae-focus`
and, inside tmux, selects the command's pane without switching any client. The
command line reaches the hook as arguments and is never evaluated.

On `nerv`, the case's power key opens Seele Shell's Power panel instead of
shutting the machine down, and a second press puts the panel away. The
`power-key` Home Manager feature owns this. Its `seele-power-key` user service
holds a logind `handle-power-key` block inhibitor for as long as the graphical
session runs, and its `XF86PowerOff` binding runs the same toggle as
`Super + Escape`. logind.conf is left alone on purpose. The greeter, a bare TTY,
and a session whose unit polkit refused keep logind's clean poweroff, so a
failure falls back to the old behaviour rather than to a dead key. While the
session is locked the key does nothing, because the lock screen carries its own
Power grid. The firmware's hold-to-off override is untouched. See the Seele
skill's architecture reference for the logind and polkit facts it rests on.

On `nerv`, `Super + scroll` zooms the output under the pointer in and out,
`Super + Plus` and `Super + Minus` step it, and `Super + 0` resets it. The
German layout puts `=` on Shift + 0 and Hyprland matches the unshifted symbol,
so the dedicated + key stands in for it. The `screen-zoom` Home Manager feature
owns the binds, which also work while locked because the lock screen is
magnified with everything else. Each runs `seele-shellctl zoom`, whose native
helper reads Hyprland's `cursor:zoom_factor` back on every step rather than
keeping a level of its own, and writes it through one `hl.config` call, since a
Lua configuration refuses `hyprctl keyword`. Steps are quarter octaves for a
scroll notch and half octaves for a key, clamped from 1x to 8x on one grid, so
stepping down always reaches exactly 1. The shell's level OSD shows the factor
and withdraws at 1x; Hyprland magnifies that layer with the rest of the output,
so it is only legible while the view includes the top edge. Nothing resets the
zoom at login: a new session and a configuration reload both start at
Hyprland's default of 1.

On `nerv`, `Super + Ctrl + Tab` returns to the previous workspace through
Hyprland's native workspace history. `Super + Tab` and `Super + Shift + Tab`
still move the current workspace to the next and previous monitor.

Seele Shell owns `org.freedesktop.Notifications` through Quickshell's native
notification server; mako stays disabled. The shell handles actions, resident
and transient lifetimes, a 30-second default toast timeout, permanent/pinned
toasts, app stacks, local images, progress, verification-code copying, and
per-notification reminders that return a waiting notification as a toast at a
chosen time, held back by Do Not Disturb. A
local notification image leads its card as the rounded sender identity, while
the sending application's icon moves to a lower-right badge instead of the
image being repeated in the body. Toasts declare no keyboard interactivity,
so an arriving notification never interrupts typing. Only the deliberately
opened notification panel takes keyboard focus. Do Not Disturb is one control in the panel
header: its mark reports silence, the time beside it counts a running period
down, and it drops a menu of every way to set that silence -- 15 minutes, 1
hour, 4 hours, no end, and the way out -- so no row below the title is spent
on it. Two further rows appear only while they apply. While the focus timer is
running, the menu can sync silence with it: focus on turns shell Do Not Disturb
on, and focus off puts back the silence from before that sync. While a timed
calendar event is underway, the menu offers holding silence until that event
ends and highlights the row; choosing it arms the hold, and the meeting's end
puts the previous silence back. Opening the menu never arms either hold. A
later manual choice replaces both and does not start or stop the focus timer.
The shell is imported on `nerv` only, so `asuka` does not carry the menu. Notification state and DND
belong to a resident Rust policy object owned by Qt; the QML store holds native
notification objects and delivers callbacks. The hardware feed is independent. History,
pins, reminders, and a running quiet period survive QML reloads in memory; notification
text is never written to disk. See the `seele-shell` skill for the protocol
and tests.

On `nerv`, a focus timer that runs out plays one screen-edge wash in the
timer's Done green. The wash maps on each output only while it plays, takes no
keyboard focus, and passes pointer input through an empty layer mask. Pause
and cancel do not play it. The existing completion notification stays. The cue
does not read or write Do Not Disturb, so a quiet period synced to the timer
still ends on the timer leaving `running`.

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
The `rb` Fish abbreviation runs `seele-rb`, the reviewed workflow: it records
the Jujutsu working copy, runs the flake checks, builds with `nh os build`, shows
`nvd diff` against `/run/current-system`, and then activates only that built
store path. `rb --dry-run` never activates, `rb --switch` activates without
asking, and plain `rb` asks on a terminal. A failed step activates nothing and
enters the same consent path.

On `nerv`, `modules/hosts/nerv/memory-pressure.nix` decides who dies when
memory runs out. NixOS starts systemd-oomd by default but places no cgroup
under its management, so this leaf puts `system.slice` there alone and holds
the root and user slices out on purpose: `uwsm` runs Hyprland and everything it
launches inside one session cgroup, so managing user slices would offer oomd a
single candidate that takes the compositor, the shell and every window with it.
Policy is memory-pressure only, never swap, because the machine's zram is meant
to be full. `nix-daemon.service`, which holds every build, is discounted toward
the kernel's own killer and throttled with `MemoryHigh` rather than capped;
logind and greetd are marked `avoid`, and the user manager is discounted away
from system services, which only the system manager may do.

`modules/features/system/firmware-updates.nix` publishes
`flake.modules.nixos.firmware-updates`, which the NixOS `linux` profile imports.
It enables fwupd, whose own daily timer refreshes the LVFS metadata, and pins
`P2pPolicy` to `nothing` so a later upstream default does not start sharing
downloads on the local network. A separate `seele-firmware-check` timer reads
only what that refresh left behind: `fwupdmgr get-updates --json` reports
success whether or not anything is pending, so the pending set comes from the
payload, and a payload that no longer parses fails the unit instead of reporting
silence. The native `desktop-tools` helper bounds vendor data and strips control
and invisible direction characters before announcing through systembus-notify, which forwards a root service's
system-bus message into Seele Shell's notification server. A pending set is
announced once, recorded under `/run`, and so announced again after a reboot
rather than every day. Nothing installs anything:
`fwupdmgr update` stays a deliberate decision, and a UEFI capsule is staged
through fwupd's own EFI binary, which this host's custom Secure Boot keys do not
sign. `systemctl start seele-firmware-test` sends the same message without a
vendor publishing one.

A rebuild that only takes effect after a restart says so in System Health on
`nerv`. The maintenance service's `restart` source compares
`/run/booted-system` with `/run/current-system` once the session starts and on
its shared 60-second interval, so it follows every way of activating without a
hook in any of them. It looks only at what `switch-to-configuration` cannot
replace in place: the kernel, its module tree, the initrd, kernel parameters and
firmware, which only a boot loads; the systemd build that `systemd-logind` keeps,
because NixOS re-executes PID 1 but never restarts logind; the system bus binary,
which NixOS only reloads; and the switch inhibitors modules declare. One
`eventually` finding names each change, such as "Linux 6.12.8 → 6.12.10", never
notifies, and resolves after a reboot into the current generation or a rollback
to the booted one. Its Open Power action runs `seele-shellctl power`, and nothing
restarts on its own. Both links are world-readable, so unlike the firmware and
disk-health reporters it needs no root publisher. See
`seele-shell/projects/maintenance/README.md` for the reasoning behind each part.

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
Seele skill's `shell-integrations.md` for the active dictation integration and
the `seele-shell` skill for the Notes protocol, editor, and validation.

Vicinae's managed extension lives in `seele-shell/projects/vicinae/`. It exposes
live controls, audio device selection, window/workspace search, keybindings,
NixOS generation rollback, Caffeinate sessions, and one direct command per Seele panel. For extension
changes, read its `README.md`; the shell package bundles the manifest's command
entries and runs its focused checks. Home Manager installs the whole extension
directory through `xdg.dataFile`, so a new command needs no parent-side change.
Every command declares its own search keywords. Live rows state what they are
through coloured tags and state-matched icons, window rows can close or force
quit through the desktop's existing validated `application` endpoints, filter by
workspace, and move through the native validated workspace action. Copy Clean
Link adds an explicit clipboard preview and copy command; see the shell
integration reference and the extension README for both workflows. Polled views keep their loading indicator for
the first load and an explicit refresh only. `projects/vicinae/ui.tsx` owns the
shared scalar presentation, and only icon names present in both the Raycast
typings and Vicinae's own enum are used, because Vicinae resolves `@raycast/api`
to its own icon set.
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

On `nerv`, `modules/features/system/noise-suppression.nix` publishes
`flake.modules.nixos.noise-suppression`, which
`modules/hosts/nerv/noise-suppression.nix` imports into the host aggregate. It
contributes one PipeWire `libpipewire-module-filter-chain` drop-in running the
RNNoise LADSPA plugin and publishes the result as an ordinary `Audio/Source`
node, so the Seele Shell Audio panel and Vicinae's audio picker select it like
any other microphone. It is offered, never imposed: nothing here writes a
default source, the hardware microphone keeps whatever selection WirePlumber
already holds, and microphone selection stays exclusive. The filter's capture
side is passive and names no `target.object`, so one virtual source follows
an eligible microphone instead of pinning a machine-specific node name.
PipeWire automatically groups both filter endpoints; WirePlumber excludes
that group when linking capture, so selecting the virtual source as default
does not feed it its own output. The plugin is referenced through the package's `ladspa` output by store
path, and the module loads with `nofail`, so a plugin that will not load costs
the virtual source rather than the audio server. It adds no WirePlumber rules
and leaves the Bluetooth receiver's `bluez5.media-source-role` rules untouched.

On `nerv`, the shell's resident status monitor warns when a device's battery
runs low. Every battery list it publishes — system supplies, OpenLogi devices and
connected Bluetooth peripherals — passes a native policy that raises one ordinary
notification at 15% and one critical notification at 5% for a discharging
device, and re-arms only once that device is seen charging or back at 25%. What
has been said is kept in the private runtime directory, so a shell reload does
not repeat it and a reboot starts fresh. See the submodule's
`projects/tools/README.md`.

On `nerv`, the Camera panel carries every attached Litra Glow, each with its
own settings. The shell's resident status monitor owns the lights, not the
panel: OpenLogi's light commands cannot read a light back, so the monitor keeps
each light's mode (`Off`, `On` or `With camera`), brightness and colour
temperature by OpenLogi identity in a private config file, applies them when
that light appears, changes or, in camera mode, when the PipeWire camera signal
starts or stops, and reports the power it applied. It writes nothing to a light
before a first choice and never switches off on an unknown graph. A light that
is absent or refuses a write is hidden until a retry succeeds; several lights
are numbered in identity order. OpenLogi's own light settings should stay unset
so two owners do not race on reconnect. See the submodule's
`projects/tools/README.md`.

On `nerv`, Caffeinate keeps the machine awake, its displays on and its session
unlocked while one explicitly started session is active. The `seele-caffeinate`
user service holds a single systemd-logind `idle` block inhibitor, which
suppresses both Hypridle listeners and logind's own idle action. It takes no
`sleep` inhibitor, so explicit Lock and Suspend keep working, and other
applications' inhibitors are untouched. A session runs until stopped, until an
absolute deadline, or until a selected process, recognized build or transfer
ends; every ending releases it silently and returns control to the normal idle
policy without locking or suspending. A process is tracked by its start time and
pidfd and a transfer by its group id and terminal state, so PID reuse and the
transfer service's own lifetime cannot extend a session. One session exists at a
time, a start replaces it, and nothing is persisted, so none survives a reboot.
The Vicinae command starts and stops sessions; the shell contributes a
conditional coffee bar item and a compact panel with the same session and Stop.
See `seele-shell/projects/caffeinate/README.md` for the inhibition boundary, the
protocol and its validation.

Presentation mode on `nerv` holds back toasts and takes personal text off the
bar. It covers the active window's title, the calendar event's title, media
track text and artwork, and the Home Assistant readings. A `Presenting` bar item
says the mode is on. It is chosen through `seele-shellctl presentation` or
Vicinae's **Seele Presentation Mode**. It is also implied, without keeping the
session awake, while the screen is shared. A chosen mode keeps the session awake
by borrowing Caffeinate: it starts a session only when none is running and ends
only that one. It never writes Do Not Disturb, so ending it has nothing else to
restore. See the `seele-shell` skill for ownership and tests.

The Audio panel's microphone test is the resident `seele-mic-test` worker,
started by the panel and ended with it. It offers a five-second sample held only
in memory and replayed through the chosen test output, and a live monitor that
streams through a bounded private pipe without accumulating audio. Both name
their capture and playback devices explicitly, so neither changes the system
default nor moves another application's stream, and the test output selector
chooses only where this test plays. Levels and clipping are measured from the
captured samples rather than from playback, monitor sources are refused as
inputs, and a microphone another application is already using requires explicit
confirmation that mutes, stops and reroutes nothing. A microphone or test output
that disappears ends the test and is named instead of being replaced. Closing
the panel stops capture and playback and discards the sample; nothing reaches
disk. See `seele-shell/projects/tools/README.md` for the protocol and the
private-PipeWire fixture.

The Now Playing panel and the Control Center's media module are one block. Both
draw `MediaBody` at `mediaBodyHeight` on a card, so opening the module does not
unframe what was clicked, and both follow one selected player. Pure media policy,
including capability projections and timeline labels, lives in `qml-core`; QML
retains object identity, layout and interaction. With no player the panel shows
one shared empty state. With a player it keeps the volume rule available to state
unsupported or read-only capability, and offers speeds through `PanelPicker` only
when there is a choice. The timeline is the shared `MeterBar`; controls use an
explicit focus indicator appropriate to their shape.

On `nerv`, the `seele-transfers` user service automatically receives Taildrop
files into the configured XDG Downloads folder with exclusive numbered names
and user-owned mode-0600 files. The shell owns the Transfers panel, Control
Center module, conditional progress bar item, and provider-neutral contract.
The panel's layershell namespace is `seele-shell-transfers`, and it belongs in
the Hyprland blur rule.
The service selects only currently available targets owned by the logged-in
Tailscale user. It retains seven days of metadata, never file contents; clearing
history never deletes files. `asuka` has no transfer service. See the submodule's
`projects/transfers/README.md` for protocol, tests and Taildrop's incoming
identity/cancellation limitations.

The `trash` Home Manager feature makes deletion recoverable on Linux. It installs
`trash-cli` and abbreviates `trash-put`, `trash-list` and `trash-restore` to `tp`,
`tl` and `tre` in Fish. `rm` is deliberately not shadowed: an interactive alias
would not cover scripts, non-interactive ssh or `run0`, and `trash-put` accepts
none of `rm`'s `-r`/`-f`/`--one-file-system`, so the safe path is made shorter
than `rm` instead of replacing it. `trash-empty` gets no abbreviation, because it
is the one irreversible command in the set. A `trash-empty.timer`/`.service` pair
expires entries older than 30 days daily, `Persistent` so a machine that was off
catches up, with an hour of jitter to stay off the login path; the service names
`trash-empty` by store path, passes `-f` so it can never acquire a prompt, and
sets `XDG_DATA_HOME` from `config.xdg.dataHome` because the user manager does not
necessarily carry the session's value. Yazi's `d` writes the same
`$XDG_DATA_HOME/Trash`, so the CLI and the timer cover file-manager deletions
too. `trash-put` never crosses a mount: it uses the home trash for the home
volume and otherwise creates `$topdir/.Trash-$uid`, failing loudly on a volume
where it cannot, and the timer prunes those per-volume directories as well. The
feature is Linux-only although `trash-cli` is `lib.platforms.unix`, because on
`asuka` it would fill a `~/.local/share/Trash` that Finder neither shows nor
empties, beside a Trash macOS already has.

GitHub's Notifications tab is backed by the resident Rust `seele-github-inbox`
worker. It loads unread notifications only, because GitHub keeps web-Done threads
in its read listing and exposes no Done state, and uses the shared
Codex broker for automatic triage without reading changed files or diffs. Raw
notifications remain available on AI failure; opening a row never marks read.
Rows carry priority as a chip and unfold in place to show actions, analysis and
the original thread.
Only urgent priorities produce desktop notifications. Done synchronizes explicitly
with rollback on failure. Saved state, Save/Unsave and Undo-Done are deferred to
GitHub's web inbox because the public API lacks them; this is the approved SIL-40
scope. See the Seele skill's `shell-integrations.md` and the shell's
`projects/github/README.md` for limits, reconciliation and fixture validation.

On `nerv`, `seele-shellctl pr-focus` enters or leaves focus on one configured
pull request (`SEELE_FOCUS_PULL`, or `seele-shell/focus.json` when that variable
is unset). While focus is on, the Control Center pins that pull request's check
rollup and latest review comment; exit clears the pin. The same session defers
desktop toasts that are not @-mentions and keeps those notifications in the
inbox, then shows the held toasts when focus ends. @-mentions, including a
GitHub "mentioned you" summary, still arrive immediately. Focus is not written
beside notification text, and nothing is posted to chat or email. Entering when
a branch is pushed or a pull request URL is opened stays out of this slice.

Home Assistant's house icon stays visible before setup. Its panel groups named
sensor readouts and expandable device controls into Favorites and room cards,
with a searchable device picker and an output-bounded viewport. It stores the token
through the standard Secret Service interface and keeps only connection metadata
and display preferences in its private JSON file. See the Seele skill's
`shell-integrations.md` reference for live state, per-device confirmation,
room/favorite organization and fixture validation.

Google Calendar's agenda is inside the existing clock/calendar popup. The native
`seele-calendar` worker in the shell integrations crate owns desktop OAuth with
PKCE, the Secret Service refresh token and optional OAuth client secret, the
private cache, every calendar policy and durable reminder keys. It fetches in
the background and publishes small sections -- account, calendars, day dots,
the selected day's agenda and the bar's event -- each only when it changed, so
QML never parses or filters events and nothing waits for Google. The popup keeps
one month above the agenda and puts account and calendar choice behind a header
gear; the clock-adjacent indicator opens its event unfolded on its day. The shell
feature registers a Calendar entry in Integration Health, whose Settings action
opens that view.
Calendar colors remain Google's configured colors; the rest of the UI uses
Seele tokens. The integration is read-only and supports one account. The World
Clock planner reads the same cache as busy time. See
`seele-shell/projects/integrations/CALENDAR.md` for OAuth client setup, the
worker protocol, sync windows, cache limits and the fake-API and QtTest checks.
Use the `seele-credentials` skill for future integration credentials.

Local weather is one line under the same popup's header, unfolding in place into
the next eight hours, the week on one shared temperature scale and a place
search. The resident native `seele-weather` worker in the integrations crate
owns Open-Meteo forecasts and geocoding (no key, no account), a private
`$XDG_STATE_HOME/seele-weather/state.json`, units from the locale's own
measurement data (metric by default), WMO conditions and glyphs, place-local
times and every label, and publishes changed-only sections that QML only draws.
The default place is the system timezone's reference city in the tz database,
shared with the theme switcher through `seele_runtime::timezone`; no location is
asked for or stored, and Open-Meteo receives that city's rounded coordinates.
A place picked from the search, by result id only, lives in the worker's state
file until Use timezone city clears it, never in the flake. Refreshes run every
half hour with jitter and after a resume. A failed fetch keeps the last forecast,
marks it stale and backs off quietly, with no notification and no bar item. The
shell feature registers Weather in Integration Health; its Settings opens the
popup unfolded. See `seele-shell/projects/integrations/WEATHER.md` for the
protocol, presentation, cache bounds and the fake-API and QtTest checks.

On `nerv`, one configured meeting opens a local scratchpad. `seele.meetingScratchpad.event.id` and `.title` name that recurring event; with both empty, nothing is configured. From two minutes before it starts until it ends, the calendar worker writes a private markdown note under `$XDG_STATE_HOME/seele-meetings` with the title, the attendees, and empty Who, What and When sections, and opens it in Neovim. The guest list is fetched for that occurrence only and is not stored in the calendar cache. When the meeting ends, the same file stays where a later status draft can read it, including edits made in the open note. The feature is not imported on `asuka`, the note is not written into the Obsidian vault, and nothing is sent by email or chat. See `modules/features/programs/meeting-scratchpad.nix` and the calendar guide's meeting-scratchpad section.

On `nerv`, the Control Center's Ports tile opens a local TCP listener
inspector. The resident `seele-ports` worker in the shell submodule's `tools`
crate owns discovery, ownership, privilege and action policy; QML owns the
panel and its confirmations. It reads `/proc/net/tcp` and `/proc/net/tcp6` in
the host network namespace and lists listening sockets only, showing the actual
binding and leaving metadata the kernel will not show explicitly unknown.
Listing contacts no service and raises no authentication prompt. Copy and Open
are explicit, propose only HTTP or HTTPS, and build the URL natively. Stop is
confirmed, targets a systemd listener's service and an unmanaged listener's
selected process, discloses reactivation conditions, and never disables a unit.
Force stop is a separate confirmation the backend refuses until a graceful
attempt left the listener bound. A system unit or another user's process goes
through `run0` and the packaged `seele-stop-listener` helper, which takes a
typed target rather than a command and revalidates it after authentication.
Identity is the socket inode and the process start time, so a stale
confirmation is refused rather than redirected, and a listener still bound
afterwards is reported as remaining. The panel keeps nothing on disk and
collects no logs. The panel's layershell namespace belongs in the Hyprland blur
rule. See the Seele skill's `shell-integrations.md` and the submodule's
`projects/tools/README.md`.

On `nerv`, the Control Center's Fix me tile compares three live facts with the
flake and can put the drifted ones back. Quad9 DNS-over-TLS, rootless Podman
and the remote-shell boot policy are the allowlist; `modules/hosts/nerv/drift.nix`
publishes them as `/etc/seele/drift.json`, and the Quad9 server list is the same
value `dns.nix` installs. `seele-drift diff` only reads `resolvectl` and
`systemctl show`. Restore runs only the checks the panel still has selected, and
only those that are still drifted: it restarts `systemd-resolved` and reverts
links that took `~.`, stops and disables a rootful Podman or Docker socket and
starts the user socket, and enables Tailscale while disabling OpenSSH at boot
without stopping a session that is already open. The privileged half is
`seele-restore-drift`, reached through `run0`, and it accepts one of those three
ids rather than a command. The panel shows each check's current line and the
line the flake would restore. A later quiet morning audit is not part of this
slice.

The shell's local workbenches are Calculator, Colour Lab, Text workbench and the
World Clock's Plan meeting mode. Calculator and text documents, including undo
history, disappear when their panels close; clipboard operations are explicit.
Native Rust owns expression parsing, unit conversion, colour/contrast policy,
text transforms and timezone calculations. Meeting planning works on this
computer's local day, 23 or 25 hours long across a transition: every local and
pinned IANA zone is an hour ribbon against an explicitly labelled weekday
09:00–17:00 guide, one band marks the meeting across them, and ranked
suggestions and Next fit weigh those hours and, once Google Calendar is set up,
the selected calendars' busy time. The planner reads that calendar and never
writes it; Open in Google Calendar hands a prefilled draft to Google's editor.
Colour Lab accepts opaque sRGB colours and can explicitly use the
last screen-picked colour. The Control Center sets its utilities -- System
Health, Fix me, Transfers, Resources, Network activity, Ports and the three workbenches
-- four to a row as glyph tiles under the module tiles, fits the focused output
and scrolls only on an output too short for it; Vicinae exposes each workbench
directly. Every Control Center module is reachable from the keyboard.

Resources, Network activity and Sensors are local, read-only shell panels. Their native
workers sample only while the owning panel is open and retain bounded histories
in memory. Resources reads CPU, memory and process names without command-line
arguments, and lists the space on each mounted block-device filesystem from
`statvfs`, one row per device, on a sampler thread of its own so a stalled disk
marks only that group stale. Its meters turn at the Maintenance disk source's
85% and 95%. Network activity reads interface counters without contacting a host
or examining packets. Sensors, opened from the Resources header, reads hwmon
temperatures and fan speeds with only the limits their drivers state, and leaves
`drivetemp` disks alone because reading them can reset a spin-down timer.
Kernel identities and fresh baselines keep restarted
processes, replaced interfaces and rebound sensor drivers from inheriting a
previous object's rates or peaks.
The parent supplies the new layer namespaces to the existing Hyprland blur rule;
no service or host keybinding is needed. See `docs/shell-workbenches.md` for entry
points, validation and the source-only PR integration boundary.

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

On Linux, the Brave feature contributes an owned managed policy file at
`/etc/brave/policies/managed/seele.json`, imported by the NixOS `linux` profile.
It disables product analytics and anonymous usage pings through
`BraveP3AEnabled` and `BraveStatsPingEnabled`. Both policies apply after Brave
restarts; `brave://policy` reports their effective state. The Home Manager
feature still owns the browser package, extensions and Qt integration, and
this machine-policy contribution does not reach macOS.

On Linux, `modules/features/desktop/default-applications.nix` is the single
owner of file-type defaults. It associates images with imv, video and audio with
mpv, PDFs and EPUBs with zathura, text (including JSON) with the configured
Neovim, and directories with Yazi. It declares the two entries those terminal
applications lack: `seele-editor.desktop` and `seele-files.desktop` open the
configured terminal through explicit store paths rather than the launching
process's `PATH`. The Zen feature keeps only the web documents and URL schemes
it owns and claims neither `text/plain` nor `application/json`, so the two
features cannot define the same association twice. Each viewer keeps its own
feature leaf, its own vi-shaped bindings, and a Linux-only portable application. The image entry,
`seele-images.desktop`, opens one picture with its neighboring files in imv,
starting at the selected picture; multiple selections stay limited to those
files. Directory navigation remains nonrecursive.

Theme ownership is split deliberately. Catppuccin themes supported application ports and supplies the Papirus icon theme. Stylix owns Qt and GTK widget themes, fonts, and active targets without a Catppuccin module. Qt's qt5ct and qt6ct settings reuse the Catppuccin Papirus icon theme. `stylix.autoEnable` stays off, and each platform profile lists its active Stylix targets explicitly so dormant applications do not add configuration or packages. Seele QML clients receive the selected palette through generated `theme.json`; `seele-shell/projects/shared/Palette.js` is their single unmanaged fallback and shared assignment path. The pointer belongs to Stylix as well: `modules/features/themes/cursor.nix` derives the `catppuccin-cursors` output and theme name from the shared flavor and accent and sets `stylix.cursor`, which is not a target and therefore applies while `stylix.autoEnable` is off, reaching GTK, Qt/KDE, and X11 through the targets already listed. Its Home Manager module additionally gives Hyprland the theme in the compositor's own environment, and its NixOS module installs the theme system-wide, points the `default` cursor theme at it, and exports `XCURSOR_THEME`/`XCURSOR_SIZE`, because the greeter runs before any user profile exists. One declared size covers every surface. macOS draws its own pointer and stays untouched.

On `asuka`, the Homebrew feature sets `HOMEBREW_NO_ANALYTICS=1` both in the
system shell environment and in nix-darwin's `homebrew.onActivation.extraEnv`.
The latter covers privileged `brew bundle` calls, which do not inherit the
user's shell environment.

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
Pi/OpenCode lifecycle adapters and Cursor's system-layer hooks call the shared
native `seele-agent-hook`; the adapters never write state files themselves. Native lock/greeter/Notes launchers live in
`projects/tools/src/launch.rs`. A detached lock must survive launcher completion
and confirmation failure; run the synthetic launcher fixtures after changing
subprocess ownership. Never exercise these tests against a real desktop.
Do not expand these API exceptions into new runtime scripting. See the Pi
adapter README for its exact boundaries.

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

## Dependency update CI

Dependabot schedules weekly Nix flake updates. `.github/workflows/dependabot-nix.yml`
runs from `main` through `pull_request_target`. It builds `nerv` only for a
same-repository Dependabot pull request whose base is `main` and whose diff is
`flake.lock` alone, using main's Nix sources plus that lock. The build job is
`contents: read` and clears GitHub tokens before Nix. When that build fails,
Copilot may edit ordinary `*.nix` files in a later read-only job; Git metadata
is restored before Nix runs again, still with tokens cleared. `contents: write`
belongs only to the publish job, which sends those files with
`createCommitOnBranch` and does not run Nix or Copilot. `COPILOT_GITHUB_TOKEN`
is an external setup requirement, never a repository file. Darwin needs
separate native validation.

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

Validate `asuka` on Darwin and `nerv` on Linux. Complete Darwin evaluation on Linux can try to realize Darwin-only Catppuccin assets and fail with a platform mismatch; report that boundary. `nix flake show` and `nix flake check` evaluate `darwinConfigurations.asuka`, so on Linux they stop on that Catppuccin palette mismatch. The Linux host check that completes is the `nixosConfigurations.nerv` derivation above.

Activation changes the live machine. Run `nh os switch`, `nh darwin switch`, `nixos-rebuild`, `darwin-rebuild`, `rb` or `rb --switch` only when the user explicitly requests activation. `rb --dry-run` builds and diffs without activating.

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

## Cursor Cloud specific instructions

Cloud agents run on x86_64 Linux without systemd. The environment installs Determinate Nix and starts `nix-daemon` before work begins, and `install` checks out the `seele-shell` submodule. Use the Validation commands. On this machine, the Linux host check is the `nerv` derivation eval. `nix flake show` and `nix flake check` stop on the Darwin palette boundary above. Do not activate either host.
