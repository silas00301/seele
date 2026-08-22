---
name: seele
description: Develops and validates Seele's dendritic NixOS, nix-darwin, Home Manager, package, overlay, and flake configuration. Use for programs, services, hosts, packages, overlays, inputs, themes, or system settings in Seele.
compatibility: Requires Nix with flakes. Full host validation must run on the host's native platform; activation requires nh and explicit user approval.
---

# Seele workflow

Use this workflow for every repository change involving Nix configuration. Read [the architecture map](references/architecture.md) before changing composition, profiles, module arguments, packages, overlays, or hosts.

## 1. Protect the working copy

```sh
jj status
```

Record existing changes and preserve them. Use Jujutsu for change tracking and history operations. If a new file is not tracked automatically, run `jj file track <path>`.

## 2. Find the active configuration path

Classify the change:

| Scope | Dendritic contribution |
| --- | --- |
| Both hosts, user-level | named feature + `modules/profiles/home/common.nix` |
| Linux user-level | named feature + `modules/profiles/home/linux.nix` |
| macOS user-level | named feature + `modules/profiles/home/darwin.nix` |
| One user's host | named feature + `modules/profiles/home/nerv.nix` or `asuka.nix` |
| Both systems, system-level | both `flake.modules.nixos.common` and `.darwin.common` |
| One OS or machine | matching NixOS/darwin `linux`, `darwin`, `nerv`, or `asuka` profile |
| Reusable derivation | `modules/packages/` via `perSystem.packages` |
| Package-set override | `modules/flake/overlays.nix` |
| Inputs/global composition | `flake.nix`, `modules/flake/`, or host constructors |

Every `.nix` file below `modules/` is imported recursively unless its path contains `/_`. Imported leaves must be flake-parts modules. Home Manager profiles import named features in activation order; an unimported named feature is dormant.

Search before introducing a second setting or package:

```sh
rg -n 'option-or-package-name' --glob '*.nix' modules
```

## 3. Implement narrowly

- Keep a feature's Home Manager, system, and flake contributions together when they express one concern.
- Publish reusable modules as `flake.modules.<class>.<name>`.
- Enable named features from the narrowest matching Home Manager, system, or host aggregate, preserving import order.
- Consume `seele.hosts.<name>.username`, `seele.catppuccin`, and host-provided arguments instead of duplicating constants or importing nixpkgs.
- Keep non-flake-parts Nix package/config assets in an underscore-prefixed path.
- Use `lib.mkForce`, `lib.mkDefault`, and conditionals only when merge semantics require them.
- Preserve state versions, hardware data, lock data, identity/signing values, and live-machine state unless the request requires a change.
- Update `flake.lock` only for intentional input changes.

## 4. Format the whole repository

```sh
nix fmt
```

Inspect `jj diff` afterward and retain the repository-wide formatting result.

## 5. Validate incrementally

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
```

Evaluate the native host:

```sh
# x86_64-linux
nix eval --raw .#nixosConfigurations.nerv.config.system.build.toplevel.drvPath --no-write-lock-file

# aarch64-darwin
nix eval --raw .#darwinConfigurations.asuka.system.drvPath --no-write-lock-file
```

Build changed native outputs when warranted:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#packages.${system}.<package>" --no-link --no-write-lock-file
nix build .#nixosConfigurations.nerv.config.system.build.toplevel --no-link --no-write-lock-file # Linux
nix build .#darwinConfigurations.asuka.system --no-link --no-write-lock-file                     # Darwin
```

Platform boundaries:

- `nerv` is `x86_64-linux`; `asuka` is `aarch64-darwin`.
- `nix flake check` checks compatible current-system outputs and may omit the other platform.
- Complete Darwin evaluation from Linux can realize Darwin-only Catppuccin assets and fail with a platform mismatch. Validate `asuka` on Darwin.
- Activation commands require explicit user approval.

## 6. Synchronize agent guidance

After code/configuration changes, compare the repository with `AGENTS.md`, this skill, and [the architecture map](references/architecture.md). If the change establishes or reverses a tool, interaction, visual, workflow, or privacy preference, also compare the [`seele-taste` skill](../seele-taste/SKILL.md). Update guidance when architecture, profiles, outputs, commands, validation, conventions, workflows, or preferences changed.

## 7. Report precisely

Summarize changed paths, checks run, baseline warnings, and checks skipped or blocked by platform. Re-run `jj status` and distinguish any pre-existing work from your changes.
