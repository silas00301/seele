# Repository guide for coding agents

## Purpose

Seele is a personal, multi-platform dendritic Nix flake for one user (`silash`). It defines:

- NixOS host `nerv` (`x86_64-linux`)
- nix-darwin host `asuka` (`aarch64-darwin`)
- Home Manager profiles shared by both hosts and specialized by platform/host
- local packages (`codexbar`, `nixvim`, `pipewire-nothing`, `spt-st`, `t3code-nightly`), the `seele-shell` submodule package, and overlays

Skills live in `.agents/skills/`:

- **`seele`** — the change workflow and the architecture map. Read it for any Nix change, and its [architecture map](.agents/skills/seele/references/architecture.md) before touching composition, profiles, module arguments, packages, overlays, or hosts.
- **`seele-shell`** — anything under `seele-shell/`: the shell's subsystems, its focused builds and tests, and the submodule commit, push, gitlink, and lock flow that makes a shell change rebuild-ready.
- **`seele-style`** — how any shell surface is drawn: tokens, shared components, panel composition, hover, the menu bar. Read it before drawing, restyling, or reviewing a panel, bar entry, card, list, toast, OSD, or auth screen.
- **`seele-taste`** — the default when a request leaves a tool, keybinding, automation, privacy setting, product behaviour, or cross-platform equivalent open.

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

The subsystems themselves — Determinate Nix per platform, remote shell access, the frozen URI picker, native notifications, the Vicinae extension, portable applications, and theme ownership between Catppuccin and Stylix — are described in the [architecture map](.agents/skills/seele/references/architecture.md). Read it before changing any of them.

Shell integrations and local controls are documented in
[the integration map](.agents/skills/seele/references/shell-integrations.md).
GitHub reuses the existing `gh` login; Home Assistant reads a private local
connection file. Neither puts credentials in QML or the Nix store. Their request
workers stay separate from the hardware status stream. Clipboard actions use
stdin and acknowledge completion; notification text remains in memory.

## Editing conventions

- Follow nearby leaf style and let the flake formatter decide layout.
- Put reusable feature behavior in a descriptive named module under `modules/features/`.
- Import named user features from the matching `modules/profiles/home/` profile and named system features from the matching system or host aggregate; preserve import order.
- Keep dormant feature modules out of active profile imports.
- Contribute system-only behavior to the matching NixOS or Darwin `common`, OS, or host profile.
- Put reusable derivations under `modules/packages/` and package-set overrides in `modules/flake/overlays.nix`.
- Publish a configured program for unmanaged machines by adding `seele.portable.<command>` to its own feature leaf, named after the command it runs rather than the feature. List every feature it reads through, and narrow `systems` when the program is platform-bound.
- Consume standalone package repositories through flake inputs; keep their output wiring in `modules/packages/`. The `seele-shell` submodule is a declarative path input included through `inputs.self.submodules`; its gitlink pins the shell, greeter, lock, and polkit package sources.
- Pin binary packages whose releases are consumed directly (`codexbar` and `t3code-nightly`) with literal versions and hashes in their package leaves. Run `nix run .#update-packaged` to refresh both pins from their public release APIs; the helper also prefetches CodexBar to record its Nix hash.
- Keep raw Nix expressions that are not flake-parts modules below a path containing `/_` so `import-tree` ignores them.
- Prefer explicit package references in generated shell snippets when execution must not depend on `PATH`.
- Preserve state versions, hardware UUIDs, usernames, and signing keys unless explicitly requested.
- Update `flake.lock` only when the task changes inputs.
- Follow the `seele-shell` skill when committing and pushing the submodule and updating its parent gitlink. The path input follows that gitlink, so shell source-only revisions do not change `flake.lock`; the helper still refreshes the shell's transitive input locks.
- Use `jj file track <path>` if a new file is not tracked automatically. Use Jujutsu equivalents for restore/history operations.

## Keep agent guidance current

After every repository change, review `AGENTS.md` and `.agents/skills/seele/` against the resulting codebase. Update guidance when architecture, profiles, outputs, commands, validation, conventions, workflows, or preferences changed. Two of the other skills track things a change can silently invalidate:

- A change that adds, renames or retires a token or a shared component, or that settles how a surface is composed, belongs in `.agents/skills/seele-style/`.
- A change that establishes or reverses a preference about tools, interaction, product behaviour, or privacy belongs in `.agents/skills/seele-taste/`.

Each meaning lives in exactly one of these files. When you find the same rule written in two, delete the copy and leave a pointer.

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
