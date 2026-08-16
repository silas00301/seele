# Repository guide for coding agents

## Purpose

This is a personal, multi-platform dendritic Nix flake for one user (`silash`). It defines:

- NixOS host `pm` (`x86_64-linux`)
- nix-darwin host `wm` (`aarch64-darwin`)
- Home Manager profiles shared by both hosts and specialized by platform/host
- local packages (`nixvim`, `spt-st`) and overlays

Use the `nix-dotfiles` skill in `.agents/skills/` for the workflow and architecture map.

## Before editing

- Run `jj status` and preserve all pre-existing changes. Use Jujutsu for all change tracking and history operations; do not use Git's staging area.
- Every `.nix` file under `modules/` is recursively imported by `import-tree`, except paths containing `/_`. A leaf must be a flake-parts module, not a bare NixOS, nix-darwin, or Home Manager module.
- Determine whether a change contributes to a named module, an active `common`/platform/host profile, or only a package/flake output. Keep the narrowest correct scope.
- Do not expose credentials, SSH material, machine identifiers, or local agent/auth configuration.

## Architecture

- `flake.nix`: inputs and the `flake-parts`/`import-tree` bootstrap.
- `modules/flake/`: repository options, systems, package-set policy, overlays, and formatter.
- `modules/features/`: program, service, theme, and system leaves. Each leaf publishes deferred modules through `flake.modules.<class>.<name>`.
- `modules/profiles/home/`: shared, OS-specific, and host-specific Home Manager profiles. These import named feature modules in activation order.
- `modules/hosts/{pm,wm}.nix`: host output constructors and Home Manager integration.
- `modules/hosts/{pm,wm}/`: machine-specific deferred modules, including hardware configuration.
- `modules/packages/`: `perSystem` package outputs. Underscore-prefixed directories contain raw package assets/configuration and are excluded from recursive module imports.

Active profiles are `common`, `linux`/`darwin`, and `pm`/`wm`. Host constructors compose the matching profiles. Named feature modules remain dormant until a profile imports them.

`modules/flake/core.nix` owns `dotfiles.username`, `dotfiles.catppuccin`, supported systems, unstable `pkgs`, and OS-matched `pkgs-stable`. Host constructors pass `username`, `currentSystem`, `selfPackages`, `pkgs-stable`, `catppuccin`, and `configName` to Home Manager. Reuse these arguments instead of re-importing nixpkgs or hard-coding store paths.

## Editing conventions

- Follow nearby leaf style and let the flake formatter decide layout.
- Put reusable feature behavior in a descriptive named module under `modules/features/`.
- Enable user features by importing their named modules from the matching `modules/profiles/home/` profile; preserve import order.
- Keep dormant feature modules out of active profile imports.
- Contribute system-only behavior to the matching NixOS or Darwin `common`, OS, or host profile.
- Put reusable derivations under `modules/packages/` and package-set overrides in `modules/flake/overlays.nix`.
- Keep raw Nix expressions that are not flake-parts modules below a path containing `/_` so `import-tree` ignores them.
- Prefer explicit package references in generated shell snippets when execution must not depend on `PATH`.
- Preserve state versions, hardware UUIDs, usernames, and signing keys unless explicitly requested.
- Update `flake.lock` only when the task changes inputs.
- Use `jj file track <path>` if a new file is not tracked automatically. Use Jujutsu equivalents for restore/history operations.

## Keep agent guidance current

After every repository change, review `AGENTS.md` and `.agents/skills/nix-dotfiles/` against the resulting codebase. Update them when architecture, profiles, outputs, commands, validation, conventions, or workflows changed.

## Validation

Always format the entire repository:

```sh
nix fmt
```

Then inspect `jj diff` and run:

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
nix eval --raw .#nixosConfigurations.pm.config.system.build.toplevel.drvPath --no-write-lock-file # Linux
nix eval --raw .#darwinConfigurations.wm.system.drvPath --no-write-lock-file                  # Darwin
```

For relevant build validation:

```sh
system="$(nix eval --impure --raw --expr builtins.currentSystem)"
nix build ".#packages.${system}.nixvim" --no-link --no-write-lock-file
nix build .#nixosConfigurations.pm.config.system.build.toplevel --no-link --no-write-lock-file # Linux
nix build .#darwinConfigurations.wm.system --no-link --no-write-lock-file                      # Darwin
```

Validate `wm` on Darwin and `pm` on Linux. Complete Darwin evaluation on Linux can try to realize Darwin-only Catppuccin assets and fail with a platform mismatch; report that boundary.

Activation changes the live machine. Run `nh os switch`, `nh darwin switch`, `nixos-rebuild`, or `darwin-rebuild` only when the user explicitly requests activation.

Known baseline warnings include the nixvim/nixpkgs `follows` warning and upstream option/deprecation warnings. Compare with the baseline before attributing warnings to a change.
