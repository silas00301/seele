# Dendritic architecture map

## Bootstrap and public outputs

`flake.nix` declares inputs and calls `flake-parts.lib.mkFlake` with the recursive module returned by `import-tree ./modules`. Import-tree loads every `.nix` file below `modules/` except paths containing `/_`.

The flake exposes:

- `nixosConfigurations.nerv` for `x86_64-linux`
- `darwinConfigurations.asuka` for `aarch64-darwin`
- `packages.<system>.{nixvim,spt-st}` for all four declared Linux/Darwin systems
- `packages.<system>.seele-shell` on Linux, Seele's native Quickshell desktop shell
- `packages.x86_64-linux.{codexbar,t3code-nightly}`, the packaged CodexBar CLI and T3 Code nightly AppImage
- `formatter.<system>` backed by `nixfmt-tree`
- `overlays.{librepods,noctalia,zjstatus}`
- `modules.<class>.<name>` deferred modules from `flake.modules`
- `darwinPackages`, the `asuka` package set convenience output

`modules/flake/core.nix` enables flake-parts' `flake.modules` support, declares the four systems, owns per-host usernames and the shared Catppuccin values, and configures per-system unstable and stable package sets. `modules/flake/formatter.nix` and `overlays.nix` contribute their outputs independently.

## Deferred modules and active profiles

Feature leaves publish deferred modules through `flake.modules.<class>.<name>`, where class is `homeManager`, `nixos`, or `darwin`. Home Manager profile leaves import named features in activation order. Host and system leaves contribute to these active aggregate profiles:

| Profile | Meaning |
| --- | --- |
| `common` | shared by both hosts |
| `linux` | NixOS-specific |
| `darwin` | macOS-specific |
| `nerv` | host `nerv` only |
| `asuka` | host `asuka` only |

Named modules are available through the flake's `modules` output but remain dormant until a profile or host imports them. Home Manager profiles import user features; system and host aggregates import NixOS and Darwin features such as shells, themes, Homebrew applications, and host-only integrations. This replaces the old behavior where an unlisted file under `home/shared/programs/` was dormant.

`modules/hosts/nerv/noctalia.nix` preserves the previous Noctalia settings as the named modules `homeManager.nerv-noctalia` and `nixos.nerv-noctalia`. They are intentionally dormant while Seele Shell is active. Home Manager provides the user-level Noctalia options, while the `nerv` constructor imports Noctalia's external NixOS module; `asuka` does not import Noctalia.

`modules/features/` contains program, service, theme, and shared system concerns. `modules/profiles/home/` contains profile-wide Home Manager settings that do not belong to one feature. Raw Nix expressions cannot live directly in the recursive tree; place them below a path containing `/_`.

## Host assembly

`modules/hosts/nerv.nix` constructs `nixosConfigurations.nerv` from:

1. NixOS `common`, `linux`, and `nerv` deferred modules
2. Noctalia's dormant NixOS option module and Catppuccin's NixOS module
3. Home Manager's NixOS integration
4. Home Manager `common`, `linux`, and `nerv` profiles plus external input modules

Machine configuration and generated hardware settings contribute independently to the NixOS `nerv` profile from `modules/hosts/nerv/`. The host uses NixOS' native Limine module with Secure Boot and the shared Catppuccin theme.

`modules/hosts/asuka.nix` constructs `darwinConfigurations.asuka` from:

1. Darwin `common`, `darwin`, and `asuka` deferred modules
2. Home Manager's nix-darwin integration
3. Home Manager `common`, `darwin`, and `asuka` profiles plus external input modules

Machine system settings live in `modules/hosts/asuka/system.nix`. The same constructor exports `darwinPackages`.

## Arguments and package sets

Host constructors select `seele.hosts.<name>.username` and pass all flake inputs plus:

- the selected `username`
- `currentSystem`
- `selfPackages`
- `catppuccin`
- `self-path`
- Home Manager-only `pkgs-stable` and `configName`

The per-system `pkgs` set uses unstable nixpkgs, the repository overlays, unfree packages, and the repository's insecure-package exception. `pkgs-stable` selects the stable Linux or Darwin input according to the target system. Reuse these arguments rather than importing nixpkgs inside feature modules.

## Packages and assets

`modules/packages/codexbar.nix`, `nixvim.nix`, `seele-shell.nix`, `spt-st.nix`, and `t3code.nix` contribute `perSystem.packages`. CodexBar and T3 Code's nightly AppImage are available only on `x86_64-linux`; Seele Shell is available on Linux; their host features consume them through `selfPackages`. The non-flake `t3code-nightly-release` input locks GitHub's latest release metadata, including the AppImage digest, so `nix flake update` advances the nightly without a separately maintained version or hash. Seele Shell is a locally maintained QML shell under `modules/packages/_seele-shell/` built on upstream Quickshell. Its AI cockpit normalizes CodexBar data for every configured subscription and launches the host's managed Pi, OpenCode, Codex, and Claude Code packages through explicit paths. Every harness publishes lifecycle state into `$XDG_STATE_HOME/seele-shell/agents/`, and `seele-control` resolves the records per agent in a fixed order: native records first, then the launcher's CPU wrapper, then raw CPU samples. Pi and OpenCode publish natively from the extensions the Home Manager profile installs — Pi through `agent_start`/`agent_settled`, OpenCode through `session.status` plus permission events. Claude Code and Codex have no extension API but expose the same five lifecycle events, so `flake.modules.nixos.seele-shell-agent-status` configures both at the system layer, where they cannot collide with the mutable config those tools write for themselves: a drop-in under `/etc/claude-code/managed-settings.d`, whose hook arrays Claude Code concatenates with the user's own, and `[hooks]` in `/etc/codex/requirements.toml`, which Codex trusts without the review prompt that gates user and project hooks. Session start, stop, and permission events report waiting, prompt submission reports working, and session end deletes the record. Both call `seele-agent-hook`, which walks up the process tree to record the owning harness pid, because a hook is a short-lived child of the session it describes. Harnesses started outside all of this are still read from subtree CPU usage: a session that stays quiet for twenty seconds is waiting for input. Per-process records allow concurrent sessions; records whose process is gone report a finished run for five minutes and are then deleted, so an abandoned record cannot pin a stale status to the cockpit. `shell.qml` reads all live state from `seele-control status`. Now-playing rendering lives in `_seele-shell/media.js`, a plain JavaScript module shared by `shell.qml` and a Node test in `_seele-shell/tests/`: it labels every player `<title> · <artist>`, falls back to the album so podcasts show their show name, and collapses the second MPRIS service Spotify's embedded Chromium registers for the same track by comparing track length before titles. The local librepods overlay adds a read-only JSON status command so AirPods component batteries can join that state without exposing the accessory's private pairing material; the shell derivation carries that exact build through a passthru so its Home Manager service cannot fall back to the unoverlaid global package set. Connection changes use the shell OSD and librepods notifications are suppressed. The bar's clock and date own a searchable world-clock picker and a Monday-first, ISO-week calendar; selected zones appear only in the picker preview, while any number of persistent pins sort to the top of its list rather than adding bar entries. Calendar and ordering logic live in the shared `_seele-shell/time.js` module, while `seele-clock` resolves IANA zones and common abbreviations against packaged tzdata without changing the system timezone. The click-away and AI cockpit surfaces stay mapped with empty input masks while idle so opening a panel under a stationary pointer cannot make Hyprland lose the next menu-bar press. Shell chrome comes from one token block at the top of `shell.qml` — a single radius matching Hyprland's window rounding, the bar metrics, and the hover, press, selection, and semantic tints — applied through the `PanelSurface` and `BarItem` components so panels, buttons, and menu-bar entries cannot drift apart. Opening a panel records its output in `overlayScreen`, and the OSD records its own in `osdScreen`, so a surface stays on the screen that opened it instead of following Hyprland's focused monitor when the pointer crosses an edge. The bar and the panels are one textured material: a `SurfaceWash` gradient under the content, a tiled grain film and edge highlight over it through `SurfaceGrain`, and translucent fills that `hl.layer_rule` blurs for every shell namespace except the wallpaper and the click-away catcher. `PanelSurface` is a `ClippingRectangle` because a plain `Rectangle` cannot clip that tiled image to its rounded corners. The grain tile itself is not committed: `_seele-shell/grain.js` writes a seeded 128px noise PNG with Node's zlib during the install phase, so the asset stays reproducible and the repository stays free of binaries. The network panel reads Tailscale's local status and Proton VPN's NetworkManager connection, owns their connect/disconnect actions, and opens an interactive client only when sign-in or location selection needs the user; credentials remain in the clients' own state. The shell also consumes yubikey-touch-detector's Unix socket through its packaged watcher, keeping hardware-touch prompts in the OSD instead of the notification daemon. The webcam preview lives in a separate `CameraPreview.qml`, isolated from the main shell and preloaded asynchronously once a camera is detected so opening its panel remains immediate without letting a missing QtMultimedia backend break the shell. The wrapper extends `QML2_IMPORT_PATH` and `QT_PLUGIN_PATH` for that component. The package also ships a managed Vicinae extension for shell actions and live Hyprland keybinding search; the Home Manager feature links it into Vicinae's extension directory. Other raw package assets live in `_nixvim/` and `_spt-st/`; underscore paths are intentionally excluded from import-tree.

Package directories are no longer discovered by custom `readDir` logic. A package exists because a dendritic leaf contributes it to `perSystem.packages`.

## Validation boundaries

The interactive rebuild abbreviations remain:

- NixOS: `nh os switch`
- Darwin: `nh darwin switch -H asuka`

They activate live state and are not validation commands. Use direct `nix flake`, `nix eval`, and `nix build` commands from the skill. Darwin Home Manager theme modules can force generated Darwin assets, so Linux evaluation may fail with a platform mismatch; validate the complete `asuka` closure on Darwin.
