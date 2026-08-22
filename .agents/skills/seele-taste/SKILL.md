---
name: seele-taste
description: Applies Silas's established configuration taste when a Seele task leaves choices open about tools, UI, keybindings, workflow automation, privacy defaults, or Linux/macOS equivalents.
---

# Seele configuration taste

Use these as decision defaults, not as a mandate to restyle unrelated configuration.

## Resolve evidence first

Apply this precedence:

1. The user's current request or correction.
2. The nearest active host or platform configuration.
3. Repeated patterns in active profiles.
4. This skill.

Read the target module and trace whether it is imported by an active profile. Treat dormant feature modules, commented settings, and one-off experiments as weak evidence. Preserve an established local interaction over repo-wide consistency when they conflict. Ask before making a consequential choice when the evidence remains genuinely ambiguous.

## Design character

Aim for a **polished cockpit**: compact, keyboard-driven, information-rich when useful, visually coherent, and quiet when idle.

- Prefer declarative, reproducible configuration through Nix and Home Manager. Centralize shared values and derive generated configuration rather than creating mutable setup steps.
- Keep credentials, account identifiers, hardware identity, and other private state outside the Nix store and repository.
- Reuse an existing tool or integration before adding an adjacent one. An inactive alternative in the tree is not a reason to replace an active tool.
- Keep Linux and macOS behavior consistent in muscle memory and visual language while using platform-native implementations.

## Interaction defaults

- Use vi-shaped navigation: `h/j/k/l`, a space leader where applicable, and the same directional geometry across editor, multiplexer, and window manager.
- Favor direct numbered workspaces/tabs, predictable modifier layers, and shortcuts that compose navigation, move, and resize actions.
- Favor fuzzy search, frecency, previews, command palettes, and session launchers over deep menus or manual path traversal.
- Keep frequent actions fast and reversible. Automate routine cleanup, session setup, refetching, and integration work.
- Retain explicit gates for trust decisions, destructive operations, credentials, and live-machine activation.
- Support the mouse where it is convenient, but make the complete primary workflow keyboard-accessible.
- Hide passive chrome intelligently: auto-hide docks, compact launchers, suppress empty media/privacy indicators, and expose rich previews or status only when relevant.

## Visual defaults

- Default to dark **Catppuccin Mocha** with **Lavender** as the accent. Consume the repository's shared Catppuccin values instead of copying palette literals.
- Prefer **Maple Mono NF CN** for terminal and monospace UI; Geist Mono is an available secondary font.
- Favor rounded borders and popups, small gaps, capsule or powerline-shaped status elements, restrained transparency, and background blur.
- Use smooth, quick animation with a macOS-like spring/fade feel. Avoid startup noise, tips, changelog clutter, and ornamental motion that slows interaction.
- Balance compactness with legibility: show useful state, icons, previews, and status, but remove redundant labels and inactive widgets.
- Use 24-hour time, ISO-style dates, and Europe/Berlin when a timezone must be chosen. The desktop language is primarily English; preserve the German keyboard layout where host input is concerned.

## Preferred stack

When the request does not select a tool, preserve these active defaults:

| Concern | Default |
| --- | --- |
| Version control | Jujutsu for daily work; Git for interoperability; `gh` for GitHub |
| Interactive shell | Fish with vi bindings; keep Zsh as the system/compatibility bridge |
| Editor | Neovim/Nixvim |
| Terminal | Ghostty |
| Multiplexer | tmux |
| Search and selection | ripgrep, fd, fzf, Television, Telescope |
| Files and inspection | yazi, eza, bat, bottom, jq |
| Nix operations | `nh` for intended user rebuild workflows; direct `nix` commands for agent validation |
| Browser | Zen as the primary experience; Brave as a compatible secondary browser |
| App launchers | Vicinae/Noctalia on Linux and Raycast on macOS |

Prefer explicit package paths in generated services and bindings when execution must be independent of `PATH`. Preserve interoperability rather than forcing every tool into one implementation.

## Development experience

- Favor two-space indentation where the language or formatter permits it, relative line numbers, smart-case search, and smart indentation.
- Provide rich language intelligence: LSP, inlay hints, Treesitter, formatting, snippets, diagnostics, and contextual documentation.
- Keep completion user-controlled: offer strong suggestions and fuzzy matching without silently accepting the first item.
- Integrate navigation boundaries. Pane movement should flow between Neovim and tmux instead of trapping focus.
- Prefer previews and structured dashboards for changes, pull requests, files, and sessions.
- Optimize routine VCS flow around rebasing, autosquash/autostash, pruning, rerere, signed work, and small composable Jujutsu operations.

## Privacy and security defaults

- Disable telemetry, analytics, studies, and install tracking when the option exists and functionality does not depend on them.
- Prefer tracking protection, content blocking, privacy-oriented search, and role-separated browser containers/spaces.
- Delegate secrets to an existing password manager or hardware-backed mechanism; preserve SSH signing, YubiKey, Touch ID, and trust prompts.
- Treat application self-update controls in the context of declarative package management: updates should come through the managed system rather than bypass it.

## Resolve the characteristic tensions

- **Compact vs informative:** keep actionable state visible; make secondary detail contextual or on demand.
- **Automation vs safety:** automate reversible routine work; confirm trust, destructive changes, and activation.
- **Polish vs noise:** use color, icons, rounded geometry, and motion for hierarchy; keep startup and idle surfaces quiet.
- **Cross-platform vs uniform:** reproduce intent and muscle memory, not necessarily the same application.

When a completed change clearly establishes, reverses, or corrects one of these preferences, update this skill from active evidence. Do not promote a single host-specific necessity into a general preference.
