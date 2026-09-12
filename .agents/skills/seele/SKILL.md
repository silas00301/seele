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
| Configured program for unmanaged machines | `seele.portable.<command>` in the program's own feature leaf |
| Package-set override | `modules/flake/overlays.nix` |
| Inputs/global composition | `flake.nix`, `modules/flake/`, or host constructors |

Every `.nix` file below `modules/` is imported recursively unless its path contains `/_`. Imported leaves must be flake-parts modules. Home Manager profiles import named features in activation order; an unimported named feature is dormant.

Search before introducing a second setting or package:

```sh
rg -n 'option-or-package-name' --glob '*.nix' modules
```

Use `nix run .#portable-apps` to discover configured portable commands for the
current platform. Add `-- --all-systems` to include other platforms, `-- --json`
for structured metadata, or `-- <command>` for its features and run command.
The catalog reads declarations without building the listed applications.

## 3. Implement narrowly

- Keep a feature's Home Manager, system, and flake contributions together when they express one concern.
- Publish reusable modules as `flake.modules.<class>.<name>`.
- Publish a portable application as `seele.portable.<command>` from the leaf that configures it, naming it after the command. Its Home Manager evaluation is standalone, so list every feature it reads through and narrow `systems` for a platform-bound program.
- Enable named features from the narrowest matching Home Manager, system, or host aggregate, preserving import order.
- Consume `seele.hosts.<name>.username`, `seele.catppuccin`, and host-provided arguments instead of duplicating constants or importing nixpkgs.
- Keep non-flake-parts Nix package/config assets in an underscore-prefixed path.
- Use `lib.mkForce`, `lib.mkDefault`, and conditionals only when merge semantics require them.
- Preserve state versions, hardware data, lock data, identity/signing values, and live-machine state unless the request requires a change.
- Update `flake.lock` only for intentional input changes.

For repository authoring, `nix develop` provides the configured formatter, Nix
language server and linters, ShellCheck, jq, Python, Jujutsu, and GitHub CLI. It
adds no Nix distribution and runs no setup or activation hook.

For authentication, service privileges, network exposure or device authorization changes, consult the [configuration security audit](../../../docs/security-configuration-audit.md) and its native-host validation boundaries before changing the active profile.

## 4. Format the whole repository

```sh
nix fmt
```

Inspect `jj diff` afterward and retain the repository-wide formatting result.

## 5. Validate incrementally

From the checkout root, `nix run .#check` runs the whole-repository formatter,
flake output checks, and native host evaluation below. Add `-- --build` to
build that host without activation. It uses the caller's Nix distribution and
never updates `flake.lock`. Systems without a host only check flake outputs;
`--build` requires x86_64-linux or aarch64-darwin.

```sh
nix flake show --no-write-lock-file
nix flake check --no-build --no-write-lock-file
```

See [shell integrations and controls](references/shell-integrations.md) for GitHub, Home Assistant, local timers, notification actions and their focused validation.
Native services and helpers now belong to the shell's Cargo workspace. Run the
relevant crate's Rust tests and strict Clippy with all features enabled, then its
local fixture against the raw binary; the crate README names that fixture. Match
the locked nixpkgs Rust toolchain for final formatting and compatibility checks;
a newer local compiler alone does not prove the packaged build works. For example, from the parent:

```sh
cargo test --manifest-path seele-shell/Cargo.toml -p seele-shell-ai -p seele-failure-analysis
cargo build --manifest-path seele-shell/Cargo.toml -p seele-failure-analysis
PYTHONDONTWRITEBYTECODE=1 python3 seele-shell/projects/failure-analysis/tests/protocol.py seele-shell/target/debug/seele-failure-report
```

The shell-ai suite exercises the real private PTY/socket capture and broker
exchange. Failure-analysis fixtures cover invocation bounds, redaction, consent,
private files, exact rebuild output and systemd generation. Broker and prompt fixtures also
include optional real-Codex loopback servers proving that no tools or hostile
home instructions are exposed, including prompt resume/image turns. They use
synthetic private HOME/CODEX_HOME and synthetic authentication only.
Test fixtures may use Python/Node; runtime packages must not acquire them through
wrappers. Dynamically generated test scripts use the actual interpreter path,
not `/usr/bin/env` or `/bin/sh`, which are absent in a Nix build sandbox. Pure UI
policy fixtures exercise the Rust bridge and exact baseline behavior; actual Qt
tests still establish engine arrays/object identity, rendering and animation
contracts. Node-API and Pi footer fixtures cover the stable native ABI and
terminal-width/theme callbacks; see `projects/{qml-core,node}/README.md` in the
shell repository. If Nix is unavailable and installation is forbidden, use
existing standalone tools and report flake evaluation/build checks as unrun.

Changes under `seele-shell/` live in a separate Jujutsu repository. Read the [`seele-shell` skill](../seele-shell/SKILL.md) before editing the submodule or synchronizing it into the parent flake.

Evaluate the native host:

```sh
# x86_64-linux
nix eval --raw .#nixosConfigurations.nerv.config.system.build.toplevel.drvPath --no-write-lock-file

# aarch64-darwin
nix eval --raw .#darwinConfigurations.asuka.system.drvPath --no-write-lock-file
```

Build changed native outputs when warranted. Plain `nix build` builds the current native host closure:

```sh
nix build --no-link --no-write-lock-file
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

After code/configuration changes, compare the repository with `AGENTS.md`, this skill, and [the architecture map](references/architecture.md). A change that touches a token, a shared component, or how a surface is composed also belongs in the [`seele-style` skill](../seele-style/SKILL.md); one that establishes or reverses a tool, product, or privacy preference belongs in [`seele-taste`](../seele-taste/SKILL.md). Update guidance when architecture, profiles, outputs, commands, validation, conventions, workflows, or preferences changed, and keep each rule in exactly one of those files.

## 7. Report precisely

Summarize changed paths, checks run, baseline warnings, and checks skipped or blocked by platform. Re-run `jj status` and distinguish any pre-existing work from your changes.
