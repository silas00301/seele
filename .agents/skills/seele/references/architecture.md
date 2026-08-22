# Dendritic architecture map

## Bootstrap and public outputs

`flake.nix` declares inputs and calls `flake-parts.lib.mkFlake` with the recursive module returned by `import-tree ./modules`. Import-tree loads every `.nix` file below `modules/` except paths containing `/_`.

The flake exposes:

- `nixosConfigurations.nerv` for `x86_64-linux`
- `darwinConfigurations.asuka` for `aarch64-darwin`
- `packages.<system>.{nixvim,spt-st}` for all four declared Linux/Darwin systems
- `packages.<system>.seele-shell` on Linux, Seele's native Quickshell desktop shell
- `packages.x86_64-linux.codexbar`, the packaged Linux CodexBar CLI release
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

`modules/hosts/nerv/noctalia.nix` preserves the previous Noctalia settings as the named modules `homeManager.nerv-noctalia` and `nixos.nerv-noctalia`. They are intentionally dormant while Seele Shell is active. The `nerv` constructor imports Noctalia's external option modules so this alternate remains evaluable; `asuka` does not import Noctalia.

`modules/features/` contains program, service, theme, and shared system concerns. `modules/profiles/home/` contains profile-wide Home Manager settings that do not belong to one feature. Raw Nix expressions cannot live directly in the recursive tree; place them below a path containing `/_`.

## Host assembly

`modules/hosts/nerv.nix` constructs `nixosConfigurations.nerv` from:

1. NixOS `common`, `linux`, and `nerv` deferred modules
2. Noctalia's dormant option module and Catppuccin's NixOS module
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

`modules/packages/codexbar.nix`, `nixvim.nix`, `seele-shell.nix`, and `spt-st.nix` contribute `perSystem.packages`. CodexBar is available only on `x86_64-linux`; Seele Shell is available on Linux; their host features consume them through `selfPackages`. Seele Shell is a locally maintained QML shell under `modules/packages/_seele-shell/` built on upstream Quickshell. Its AI cockpit normalizes CodexBar data for every configured subscription and launches the host's managed Pi, OpenCode, Codex, and Claude Code packages through explicit paths. Managed Pi and OpenCode extensions publish authoritative lifecycle state for their sessions regardless of how they were launched: Pi uses `agent_start`/`agent_settled`, while OpenCode consumes `session.status` plus permission events. Per-process records allow concurrent sessions, native records take precedence over the wrapper's CPU heuristic, and process scanning remains the fallback for uninstrumented harnesses. `shell.qml` reads all live state from `seele-control status`. The local librepods overlay adds a read-only JSON status command so AirPods component batteries can join that state without exposing the accessory's private pairing material; the shell derivation carries that exact build through a passthru so its Home Manager service cannot fall back to the unoverlaid global package set. Connection changes use the shell OSD and librepods notifications are suppressed. The shell also consumes yubikey-touch-detector's Unix socket through its packaged watcher, keeping hardware-touch prompts in the OSD instead of the notification daemon. The webcam preview lives in a separate `CameraPreview.qml`, isolated from the main shell and preloaded asynchronously once a camera is detected so opening its panel remains immediate without letting a missing QtMultimedia backend break the shell. The wrapper extends `QML2_IMPORT_PATH` and `QT_PLUGIN_PATH` for that component. The package also ships a managed Vicinae extension for shell actions and live Hyprland keybinding search; the Home Manager feature links it into Vicinae's extension directory. Other raw package assets live in `_nixvim/` and `_spt-st/`; underscore paths are intentionally excluded from import-tree.

Package directories are no longer discovered by custom `readDir` logic. A package exists because a dendritic leaf contributes it to `perSystem.packages`.

## Validation boundaries

The interactive rebuild abbreviations remain:

- NixOS: `nh os switch`
- Darwin: `nh darwin switch -H asuka`

They activate live state and are not validation commands. Use direct `nix flake`, `nix eval`, and `nix build` commands from the skill. Darwin Home Manager theme modules can force generated Darwin assets, so Linux evaluation may fail with a platform mismatch; validate the complete `asuka` closure on Darwin.
