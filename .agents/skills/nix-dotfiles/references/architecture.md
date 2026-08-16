# Architecture map

## Public flake outputs

`flake.nix` imports `lib/default.nix` with all flake inputs plus the fixed `username` and Catppuccin settings. The library exposes:

- `nixosConfigurations.pm` for `x86_64-linux`
- `darwinConfigurations.wm` for `aarch64-darwin`
- `packages.<system>.{nixvim,spt-st}` for all four declared Linux/Darwin architectures
- `formatter.<system>` backed by `nixfmt-tree`
- `darwinPackages`, a convenience output that is not a standard flake schema output

Host and package outputs are directory-driven. A direct child under the corresponding `hosts/.../hosts/` or `packages/` directory becomes an output attribute.

## System module assembly

For each host, `getConfigurationModuleForSystemAndHost` imports modules in this order:

1. `hosts/systems/<os>/shared`
2. `hosts/shared`
3. `hosts/systems/<os>/hosts/<host>`

NixOS additionally receives Lanzaboote, Noctalia, and Catppuccin NixOS modules. nix-darwin sets its state/revision metadata in the constructor.

`hosts/shared/default.nix` defines the shared `username` option, Nix flake settings, basic packages, Fish support, and the user's shell. Machine-specific boot, hardware, networking, desktop, locale, and security settings for `pm` live in `hosts/systems/nixos/hosts/pm/config.nix`; do not move those into Home Manager.

## Home Manager assembly

Every host imports these project layers:

1. `home/shared`
2. `home/systems/<os>/shared`
3. `home/systems/<os>/hosts/<host>`

It then imports Home Manager modules from Catppuccin, Noctalia, Spicetify, Vicinae, Zen Browser, nix-index-database, and 1Password shell plugins.

`home/shared/default.nix` is the activation list for cross-platform program modules. Several files under `home/shared/programs/` are currently not imported; treat them as dormant configuration rather than active state.

Notable OS-specific composition:

- Shared NixOS Home Manager adds 1Password, comma, fastfetch, Ghostty, Hyprland, Pi, Spicetify, Vicinae, and spotifyd, plus desktop applications including Codex.
- Darwin Home Manager sets `/Users/<username>` as the home, imports Bitwarden, Aerospace, and JankyBorders, and adds macOS applications.
- Host `wm` adds Aerospace window rules and a small application set.
- Host `pm` adds OpenCode.

## Arguments and package sets

`getInputsForSystem` creates:

- `pkgs`: unstable nixpkgs with all repository overlays, unfree packages allowed, and the repository's insecure-package exception
- `pkgs-stable`: the matching stable Linux or Darwin package set
- all original flake inputs
- `username`, `currentSystem`, `selfPackages`, `catppuccin`, and `self-path`

Home Manager also receives `configName`. System modules receive the base inputs through `_module.args` but not the constructed `pkgs-stable` field unless explicitly passed elsewhere. Check the constructor before assuming an argument is available in every module type.

## Packages and overlays

Each direct package directory is imported with the complete system input set:

- `packages/nixvim`: builds a standalone Nixvim configuration from `nixvim.nix`.
- `packages/spt-st`: wraps `spotify-status.sh` as a binary.

Each direct overlay directory is imported for every `pkgs` instance:

- `overlays/noctalia`: exposes the matching Noctalia package as `pkgs.noctalia`.
- `overlays/zjstatus`: exposes the matching zjstatus package as `pkgs.zjstatus`.

Because discovery assumes every direct child is importable, do not add documentation or scratch directories directly under `packages/` or `overlays/`.

## Rebuild and validation boundaries

The configured interactive rebuild abbreviations are:

- NixOS: `nh os switch`
- Darwin: `nh darwin switch -H wm`

These activate live state and are not validation commands. Use the direct `nix flake`, `nix eval`, and `nix build` commands documented in the skill. Darwin Home Manager theme modules can use import-from-derivation-like generated assets, so a Linux machine may hit Darwin platform mismatches while forcing the Darwin closure even during what appears to be evaluation.

This map is maintained alongside the code. Any change to flake outputs, directory-driven discovery, module composition, hosts, package sets, or rebuild/validation boundaries must update this reference in the same change.
