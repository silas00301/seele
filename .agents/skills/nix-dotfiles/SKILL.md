---
name: nix-dotfiles
description: Develops and validates this repository's NixOS, nix-darwin, Home Manager, package, overlay, and flake configuration. Use for adding or changing programs, services, hosts, packages, overlays, inputs, themes, or system settings in these dotfiles.
compatibility: Requires Nix with flakes. Full host validation must run on the host's native platform; activation requires nh and explicit user approval.
---

# Nix dotfiles workflow

Use this workflow for every repository change involving Nix configuration. Read [the architecture map](references/architecture.md) when deciding where a change belongs or tracing module arguments.

## 1. Protect the working copy

```sh
jj status
```

Record which files were already modified and do not revert or absorb unrelated work. Use Jujutsu for all change tracking and history operations. There is no staging step in the normal workflow: never run `git add` or other Git index-mutating commands. If a new file is not tracked automatically, run `jj file track <path>`.

## 2. Find the active configuration path

Classify the task before editing:

| Scope | Location |
| --- | --- |
| Both systems, user-level | `home/shared/` |
| Linux user-level | `home/systems/nixos/` |
| macOS user-level | `home/systems/darwin/` |
| Both systems, system-level | `hosts/shared/` |
| One OS or machine | `hosts/systems/<os>/` |
| Reusable derivation | `packages/<name>/` |
| Package-set override | `overlays/<name>/` |
| Inputs/outputs/composition | `flake.nix`, `lib/default.nix` |

Follow `imports` from the relevant `default.nix`. Files in a programs directory can be dormant; existence does not imply activation. When creating a module, import it from the narrowest applicable layer.

Search before introducing a second setting or package:

```sh
rg -n 'option-or-package-name' --glob '*.nix' .
```

## 3. Implement narrowly

- Follow adjacent module structure and naming.
- Consume existing module arguments such as `pkgs`, `pkgs-stable`, `selfPackages`, `username`, `currentSystem`, `catppuccin`, or flake inputs.
- Use `lib.mkForce`, `lib.mkDefault`, or conditionals only when module merge semantics require them.
- Keep platform-specific options out of shared modules unless guarded correctly.
- Add local packages and overlays by directory; `lib/default.nix` discovers their direct child directories automatically.
- Do not alter state versions, generated hardware data, lock data, identity/signing values, or live-machine state unless the request requires it.
- If pure flake evaluation cannot see a newly imported file, track it with `jj file track <path>`.

## 4. Format the whole repository

Always run the general formatter so all Nix files match the repository scheme:

```sh
nix fmt
```

Inspect `jj diff` afterward. Separate formatter-only changes from semantic changes when reviewing, but retain the repository-wide formatting result.

## 5. Validate incrementally

Evaluate compatible outputs without updating the lock file:

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
```

Evaluate the native host explicitly:

```sh
# On x86_64-linux
nix eval --raw .#nixosConfigurations.pm.config.system.build.toplevel.drvPath --no-write-lock-file

# On aarch64-darwin
nix eval --raw .#darwinConfigurations.wm.system.drvPath --no-write-lock-file
```

For a local package change, build its direct flake target:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#packages.${system}.<package-name>" --no-link --no-write-lock-file
```

Build the native host closure only when the task warrants the cost:

```sh
# Linux
nix build .#nixosConfigurations.pm.config.system.build.toplevel --no-link --no-write-lock-file

# Darwin
nix build .#darwinConfigurations.wm.system --no-link --no-write-lock-file
```

Important platform behavior:

- `pm` is `x86_64-linux`; `wm` is `aarch64-darwin`.
- `nix flake check` checks compatible outputs for the current system and may omit the other systems.
- Complete Darwin evaluation from Linux can force Darwin-only generated theme assets and fail with a platform mismatch. That is not a substitute for validation on `wm`.
- Never activate with `nh ... switch` or a rebuild command unless the user explicitly requested activation.

## 6. Keep the agent tooling synchronized

After every code or configuration change, compare the resulting repository against `AGENTS.md`, this skill, and [the architecture map](references/architecture.md). Update those files in the same change whenever architecture, imports, hosts, outputs, commands, validation, conventions, or workflows are now stale. Leave them alone when they remain accurate; this is synchronization, not mandatory documentation churn.

## 7. Report precisely

Summarize changed paths, checks run, baseline warnings, and checks skipped due to platform or cost. Re-run `jj status` to verify that pre-existing work is still present and distinguish it from your changes.
