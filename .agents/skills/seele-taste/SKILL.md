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
- Model a persistent on/off state as a switch beside the panel title, and keep buttons for one-shot actions.
- Manage the devices or connections a panel owns inside that panel rather than deferring to an external settings application. Confirm a destructive row action in place, and escalate a step that needs a human answer, such as a pairing passkey, to an interactive terminal instead of attempting it silently.
- Let the user hide chrome they did not ask for, such as individual tray icons, and keep the hidden set reachable behind one affordance rather than dropping it.
- Reuse a running helper application instead of spawning another instance, and keep a companion app's own autostart entry disabled when a managed service already runs it.
- Integrate with a tool through its own lifecycle hooks or extension API before inferring state by observation, and declare those hooks in a layer that does not own the mutable file the tool writes itself, such as a managed drop-in or a system config layer. Keep the observational fallback for harnesses that expose nothing.

## Visual defaults

- Default to dark **Catppuccin Mocha** with **Lavender** as the accent. Consume the repository's shared Catppuccin values instead of copying palette literals.
- Prefer **Maple Mono NF CN** for terminal and monospace UI; Geist Mono is an available secondary font.
- Favor rounded borders, small gaps, capsule or powerline-shaped status elements, restrained transparency, and background blur. Match shell popup radii to the compositor's normal window radius, and align screen-edge flyout offsets with its outer window gap.
- Round every shell surface on that one radius — panels, buttons, list rows, and menu bar entries alike — and derive shape, spacing, and the hover, press, selection, and semantic tints from a shared token block instead of per-widget literals. Reserve pill and circular shapes for switches, meters, and status dots.
- Give shell chrome a textured, Zen-like material rather than flat fills: translucent surfaces the compositor blurs, a quiet vertical wash for depth, and a faint grain film over the content. Generate a texture asset at build time from a seeded script instead of committing an image.
- Keep a popup on the screen that opened it until it closes. Track the output at open time rather than the compositor's focused monitor, which would otherwise move an open surface the moment the pointer crossed a screen edge.
- Keep shell popouts, application launchers, and tooltips immediate. Reserve animation for small in-surface state changes rather than moving whole windows or layer surfaces. Avoid startup noise, tips, changelog clutter, and ornamental motion that slows interaction.
- Acknowledge asynchronous popup actions immediately without changing control geometry. Animate an in-place refresh glyph only while work is active, and briefly show completion or failure when the resulting state is not self-evident.
- Balance compactness with legibility: show useful state, icons, previews, and status, but remove redundant labels and inactive widgets.
- Label a status entry with the stable identity of the thing it tracks — the application's name, not its current window title — and let the changing detail live in the entry's value or its tooltip. Read now playing as `<title> · <artist>`.
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
| App launchers | Seele's native unified menu with Vicinae on Linux and Raycast on macOS |

Use Vicinae's standard launcher layout; Seele Shell carries the compact native desktop UI. Prefer explicit package paths in generated services and bindings when execution must be independent of `PATH`. Preserve interoperability rather than forcing every tool into one implementation.

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
