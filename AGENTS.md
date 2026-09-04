# Repository guide for coding agents

## Purpose

Seele is a personal, multi-platform dendritic Nix flake for one user (`silash`). It defines:

- NixOS host `nerv` (`x86_64-linux`)
- nix-darwin host `asuka` (`aarch64-darwin`)
- Home Manager profiles shared by both hosts and specialized by platform/host
- local packages (`codexbar`, `nixvim`, `spt-st`), the `seele-shell` submodule package, and overlays

Use the `seele` skill in `.agents/skills/` for the workflow and architecture map. Use `seele-shell` for changes inside the shell submodule, for the shell's design tokens and shared QML components, and for its rebuild-ready commit, push, gitlink, and lock flow. Use `seele-taste` when choosing tools, UI defaults, keybindings, automation, privacy settings, or cross-platform equivalents that the request leaves open.

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

Remote shell access on `nerv` is one exclusive Seele Shell selector: `off` disables both incoming paths, `tailscale` enables Tailscale SSH and stops OpenSSH, and `ssh` disables Tailscale SSH and starts ordinary OpenSSH. OpenSSH never starts automatically, accepts public keys only, and uses the normal port 22 firewall opening while selected.

Portable applications are the second way a feature reaches outside this flake. `modules/flake/portable.nix` declares `seele.portable.<app>`, and each program leaf worth running on an unmanaged machine contributes one entry beside its `flake.modules.homeManager` definition. An entry names the Home Manager features to evaluate, and the builder wraps the resulting binary so it materializes the generated `.config` tree as a symlink farm below `$XDG_CACHE_HOME/seele/portable/<app>` and puts that evaluation's own `home.path` on `PATH`. The evaluation is standalone rather than host-derived, so a feature the app reads through has to be listed or its options resolve to Home Manager defaults instead of the values a host would give them.

Theme ownership is split deliberately. Catppuccin themes supported application ports and supplies the Papirus icon theme. Stylix owns Qt and GTK widget themes, fonts, and active targets without a Catppuccin module. Qt's qt5ct and qt6ct settings reuse the Catppuccin Papirus icon theme. `stylix.autoEnable` stays off, and each platform profile lists its active Stylix targets explicitly so dormant applications do not add configuration or packages.

## Editing conventions

- Follow nearby leaf style and let the flake formatter decide layout.
- Put reusable feature behavior in a descriptive named module under `modules/features/`.
- Import named user features from the matching `modules/profiles/home/` profile and named system features from the matching system or host aggregate; preserve import order.
- Keep dormant feature modules out of active profile imports.
- Contribute system-only behavior to the matching NixOS or Darwin `common`, OS, or host profile.
- Put reusable derivations under `modules/packages/` and package-set overrides in `modules/flake/overlays.nix`.
- Publish a configured program for unmanaged machines by adding `seele.portable.<command>` to its own feature leaf, named after the command it runs rather than the feature. List every feature it reads through, and narrow `systems` when the program is platform-bound.
- Consume standalone package repositories through flake inputs; keep their output wiring in `modules/packages/`. The `seele-shell` submodule is the local flake input that owns the shell, greeter, lock, and polkit package sources.
- Keep raw Nix expressions that are not flake-parts modules below a path containing `/_` so `import-tree` ignores them.
- Prefer explicit package references in generated shell snippets when execution must not depend on `PATH`.
- Preserve state versions, hardware UUIDs, usernames, and signing keys unless explicitly requested.
- Update `flake.lock` only when the task changes inputs.
- Follow the `seele-shell` skill when committing and pushing the submodule, updating its parent gitlink, and refreshing `flake.lock`.
- Use `jj file track <path>` if a new file is not tracked automatically. Use Jujutsu equivalents for restore/history operations.

## Keep agent guidance current

After every repository change, review `AGENTS.md` and `.agents/skills/seele/` against the resulting codebase. When a change establishes or reverses a configuration preference, also review `.agents/skills/seele-taste/`. Update guidance when architecture, profiles, outputs, commands, validation, conventions, workflows, or preferences changed.

## Validation

Always format the entire repository:

```sh
nix fmt
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
