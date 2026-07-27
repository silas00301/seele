# Repository guide for coding agents

## Purpose

This is a personal, multi-platform Nix flake for one user (`silash`). It defines:

- NixOS host `pm` (`x86_64-linux`)
- nix-darwin host `wm` (`aarch64-darwin`)
- shared and platform-specific Home Manager configuration
- local packages (`nixvim`, `spt-st`) and overlays

Use the `nix-dotfiles` skill in `.agents/skills/` for the detailed workflow and architecture map. The shared `.agents/skills` location is understood by Pi, OpenCode, and Codex CLI.

## Before editing

- Run `jj status` and preserve all pre-existing changes. This repository is colocated Jujutsu/Git, but all change tracking and history operations must go through Jujutsu. Do not use Git's staging area.
- Trace imports before changing a module. A `.nix` file under `home/shared/programs/` has no effect unless an active `default.nix` imports it.
- Determine whether the change belongs to shared Home Manager, one OS, or one host. Keep the narrowest correct scope.
- Do not expose credentials, SSH material, machine identifiers, or values from local agent/auth configuration.

## Architecture

- `flake.nix`: inputs, username/theme constants, and public outputs.
- `lib/default.nix`: central constructor. It discovers package, overlay, and host directories and assembles NixOS, nix-darwin, and Home Manager modules.
- `hosts/shared/`: system configuration shared by both OS families.
- `hosts/systems/{nixos,darwin}/shared/`: OS-level system modules.
- `hosts/systems/{nixos,darwin}/hosts/{pm,wm}/`: machine-specific system modules.
- `home/shared/`: cross-platform Home Manager modules.
- `home/systems/{nixos,darwin}/shared/`: OS-specific Home Manager modules.
- `home/systems/{nixos,darwin}/hosts/{pm,wm}/`: host-specific Home Manager modules.
- `packages/<name>/default.nix`: automatically exported as `packages.<system>.<name>`.
- `overlays/<name>/default.nix`: automatically loaded for every configured package set.

`lib/default.nix` supplies flake-derived module arguments. Home Manager receives values including `username`, `currentSystem`, `selfPackages`, `pkgs-stable`, `catppuccin`, and `configName`; system modules receive the base input set. Check the constructor for the exact scope, and reuse its arguments instead of re-importing nixpkgs or hard-coding store paths.

## Editing conventions

- Follow nearby Nix module style and let the flake formatter decide layout.
- Add a new module to the appropriate `imports` list. Merely creating the file does not enable it.
- Put cross-platform program configuration in `home/shared/programs/`; put OS-only packages/options under `home/systems/<os>/`; put hardware and machine services under `hosts/systems/<os>/hosts/<host>/`.
- Add reusable derivations under `packages/` and package-set overrides under `overlays/`.
- Prefer explicit package references in generated shell snippets (for example `${pkgs.foo}/bin/foo`) when execution must not depend on the user's `PATH`.
- Do not change `system.stateVersion`, `home.stateVersion`, hardware UUIDs, usernames, or signing keys unless explicitly requested.
- Do not update `flake.lock` as a side effect of formatting or validation. Update inputs only when the task asks for it.
- Avoid broad cleanup unrelated to the task. The repository-wide formatter is the exception: always run it so every Nix file remains consistent.
- Use `jj file track <path>` if a new file is not tracked automatically. Never use `git add`, `git restore`, `git reset`, or `git commit`; use the corresponding Jujutsu workflow.

## Keep agent guidance current

After every repository change, review `AGENTS.md` and `.agents/skills/nix-dotfiles/` against the resulting codebase. Update them in the same change whenever architecture, imports, hosts, outputs, commands, validation, conventions, or workflows have changed. Do not make cosmetic documentation edits when the guidance remains accurate.

## Validation

Always format the entire repository, not selected files:

```sh
nix fmt
```

Then inspect `jj diff` to ensure formatter changes are expected. Run current-platform evaluation directly:

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.pm.config.system.build.toplevel.drvPath --no-write-lock-file # Linux
nix eval --raw .#darwinConfigurations.wm.system.drvPath --no-write-lock-file                  # Darwin
```

For relevant build validation, use the direct flake target:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#packages.${system}.nixvim" --no-link --no-write-lock-file
nix build .#nixosConfigurations.pm.config.system.build.toplevel --no-link --no-write-lock-file # Linux
nix build .#darwinConfigurations.wm.system --no-link --no-write-lock-file                      # Darwin
```

Validation is platform-sensitive. In particular, evaluating the complete Darwin Home Manager closure on Linux can try to realize Darwin-only generated Catppuccin assets and fail with a platform mismatch. Validate `wm` on Darwin and `pm` on Linux; report any platform checks that were not run.

Never run `nh os switch`, `nh darwin switch`, `nixos-rebuild`, or `darwin-rebuild` unless the user explicitly asks to activate the configuration. Activation changes the live machine and may require privileges.

Known baseline warnings include the nixvim/nixpkgs `follows` warning and some upstream option/deprecation warnings. Do not claim they were introduced by a change without comparing against the baseline.
