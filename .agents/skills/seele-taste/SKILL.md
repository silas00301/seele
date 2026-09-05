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
- Prefer user-facing packages from nixpkgs. When a narrow hardware protocol belongs inside an existing Seele component, keep that glue in the component instead of installing a separately pinned companion application.
- Keep Linux and macOS behavior consistent in muscle memory and visual language while using platform-native implementations.

## Interaction defaults

- Use vi-shaped navigation: `h/j/k/l`, a space leader where applicable, and the same directional geometry across editor, multiplexer, and window manager.
- Favor direct numbered workspaces/tabs, predictable modifier layers, and shortcuts that compose navigation, move, and resize actions.
- Favor fuzzy search, frecency, previews, command palettes, and session launchers over deep menus or manual path traversal.
- Focus a searchable popup's query field when it opens and select any retained query so typing starts a fresh search immediately.
- Keep frequent actions fast and reversible. Automate routine cleanup, session setup, refetching, and integration work.
- Let the desktop change itself: a session that edits this flake should open in the repository, rebuild on its own when the work is done, and then ask before recording it. Generate the commit message from the repository's own history and keep the decision to commit with the user.
- Retain explicit gates for trust decisions, destructive operations, credentials, and live-machine activation.
- Support the mouse where it is convenient, but make the complete primary workflow keyboard-accessible.
- Hide passive chrome intelligently: auto-hide docks, compact launchers, suppress empty media/privacy indicators, and expose rich previews or status only when relevant.
- Let the active application's menu bar entry open its application menu. Offer a graceful quit and a destructive force quit there, with force quit confirmed in place before it kills the process.
- Model a persistent on/off state as a switch beside the panel title, and keep buttons for one-shot actions. Give sibling one-shot actions the same button treatment, including alternate reboot targets.
- Show a notification whole wherever it is read and folded only where it is glanced at: the panel unfolds every entry by itself, while a toast keeps one line and offers an unfold control only when something is actually folded away. Size the row to the notification rather than the notification to the row.
- Make a notification that carries an action clickable wherever it is current, and let the whole row be that target without an arrow marking it: the hover state already says the row responds, so a glyph pointing at it only competes with the controls that do need one. Nothing expires on its own: the popup is a toast that retires after ten seconds, with a visible close button for retiring it at once, while the notification itself stays in the panel until it is dismissed there. That keeps the panel an inbox whose entries are all still actionable, and leaves history holding only what was actually dismissed — a history record is no longer actionable, so nothing should reach it without the user saying so.
- Anchor a status label that carries arbitrary text to a baseline reference in the primary font. A single glyph the font lacks pulls in a fallback whose metrics move an auto-sized label off the line its neighbours sit on, so the drift depends on the words rather than the design.
- Give a shell one aggregate control panel that carries the frequently used device modules together, and keep every module there in its own menu bar entry and dedicated panel as well: a module lives in both places rather than moving between them. Split the interaction inside an aggregate module the way macOS does. The toggle owns the state, and the rest of the row hands off to the panel that owns the detail. Keep VPN in that connectivity group while preserving its own toggle, menu bar entry, and detail panel. Let a module in the aggregate hide on the same condition its menu bar entry does.
- Let the user place the modules: dragging one out of the aggregate onto the menu bar adds its entry and dragging an entry off the bar removes it. Let the drag be the whole interface rather than hanging a placement marker on every module. The aggregate stays quiet, the way macOS shows nothing until you drag. Preview a removal by fading the entry rather than hiding it, and let a draggable entry act on release rather than on press: an item that disappears mid-gesture, or a panel that opens into the gesture's path, takes the pointer with it. Store only the choices the user actually made and let the code supply the rest, so a module nobody has moved keeps the placement it shipped with.
- Arrange an aggregate control panel on a four-column grid when modules have different weights. Lead with one wide now-playing card. Below it, put the two-column connectivity and Audio cards side by side at the same height. Give Camera the full short bottom row, then split that row evenly with supported headphones only while they are connected.
- Let a device's own control be the state, not a copy of it. When hardware carries a control the user can operate by hand — a microphone's mute panel — sync the desktop to the control the device actually publishes rather than keeping a software mute beside it, so one state drives the audio, the desktop, and the device's own indicator. Give the hardware the tie-break when the two first disagree, since it is what gates the signal, and acknowledge a change the user made on the device with the same OSD its keyboard key would raise.
- Pair output and microphone as horizontal level controls inside one aggregate Audio card, with each icon-only mute action overlaid inside its slider and no redundant names. Match those mute circles to the connectivity toggles. Give the top edge, the gap between sliders, and the bottom edge one shared padding value, and keep the sliders close to the standard button height. Let the card's unused area open the full Audio panel or drag the one sound module without taking slider or mute input away from the controls. Pack the connectivity rows together while retaining wider left and right insets.
- Let output gain reach 150% while keeping microphone gain capped at 100%. Run every level track and OSD to 100% so a full bar means full volume on the output as well as the microphone, and let a value above that move the number alone: a bar cannot draw more than full, and scaling the track to the real 150% left an ordinary volume looking two thirds set and needed a tick mark to explain itself. Dragging maps across that same 100; the boost above it belongs to the wheel and the volume keys, which stay clamped to the real limit.
- Build a wide now-playing card like iOS: large artwork on the left, track text and flat transport controls on the right, and a timeline along the bottom when the player reports seek, position, and duration support. Treat the browser's impossible full-duration sentinel as a live stream, and replace its draggable timeline with a bar split around `LIVE`. Keep the seek thumb hidden until the user is actively dragging. Put a menu bar player's artwork before its label, and hold the entry for a minute after a pause rather than collapsing it mid-track, marking the pause with a glyph over the artwork or in place of it. Let both open one larger media panel with artwork and transport controls.
- Manage the devices or connections a panel owns inside that panel rather than deferring to an external settings application. Confirm a destructive row action in place, and draw a step that needs a human answer — a pairing code to compare or to type — on the shell's own prompt card: a terminal is the fallback for a step the shell cannot render, not for one it can. Keep one list of a panel's devices rather than splitting a subset into its own section, and order that list only on what the user changes; sorting on state that moves by itself, such as whether a device is connected, pulls a row out from under the pointer aimed at it.
- Let the Camera panel select from the devices the system reports. Use that selection for its embedded preview, preview window, and settings action, and fall back to the system default if the selected camera disappears.
- Order a panel's switched rows by scope, the widest first, so the radio's switch leads and a mode that depends on it follows directly beneath, above the one-shot actions. Let this machine be an audio sink as well as a source, and match the identity it advertises to the role it is playing, since a peer decides what to offer from that rather than from the profiles on offer. Keep the machine's discoverability out of that mode: gate it behind an explicit, time-boxed window that confirms a pairing code on both ends and closes itself, and make that window symmetric under one control the way a phone's Bluetooth screen is — looking for devices and answering them are the same intent, and splitting them into two actions leaves one direction quietly unavailable.
- Hold a switch at the state the user just asked for until the system agrees. A toggle whose backing work takes about a second will otherwise be overwritten by a status poll that started before it, snapping back and then forward on its own.
- Let the user hide chrome they did not ask for, such as individual tray icons, and keep the hidden set reachable behind one affordance rather than dropping it. Expand that set only on click; hovering the affordance must not move neighboring menu bar items.
- Prefer a shell-native surface over a third-party one when the third party structurally cannot show something the design depends on — a polkit agent that logs PAM info messages instead of drawing them cannot present a hardware-token prompt, however well themed it is. Check that the replacement API actually exposes the missing signal before committing to the rewrite.
- Reuse a running helper application instead of spawning another instance, and keep a companion app's own autostart entry disabled when a managed service already runs it.
- Integrate with a tool through its own lifecycle hooks or extension API before inferring state by observation, and declare those hooks in a layer that does not own the mutable file the tool writes itself, such as a managed drop-in or a system config layer. Keep the observational fallback for harnesses that expose nothing.

## Visual defaults

- Default to dark **Catppuccin Mocha** with **Lavender** as the accent. Consume the repository's shared Catppuccin values instead of copying palette literals. Use Catppuccin's Nix modules for supported application ports and its Papirus icon theme. Use Stylix for Qt and GTK widget themes, fonts, and active targets Catppuccin cannot theme, and point Qt at the same Papirus icons. Keep Stylix auto-enable off and list its active targets by platform so dormant applications add nothing to the closure.
- Keep the lock and login screens visually tied to the desktop through its wallpaper, Maple font, generated palette, 8px geometry, and material tokens. Use the shell's translucent surface fill, grounded edge, vertical wash, grain, and interaction tints instead of an auth-specific card style. The circular profile mark keeps an accent ring, since it is the one place on those screens where the accent names whose session this is. Give each physical output its own full-screen auth surface with shared state, and crop the wallpaper to that output instead of spanning one top-level window across the combined layout. Run the lock as a small separate session-lock client. Mirror its clock, enlarged profile marker, shared password state, prompts, and popup state across every output. Show PAM information where the password was entered, and wait for the compositor's secure confirmation before suspend. Leave the lock's password control directly on the wallpaper without a surrounding card fill, and keep the profile initial on its own circular background. Use the account's declared display name when it has one, and suppress the blinking caret in the masked password field. Lead the password row with its state: the shell's arc spinner while PAM works, then the same key glyph as the YubiKey touch notification while the token waits. Replace the exposed power-action row with one bottom-left power button that opens the desktop shell's Power grid, retaining confirmation for restart and shutdown actions. The login screen is the lock seen a second time: no card behind its password control either, the same circular profile mark, the same field, and the same Power grid down to the label's size, weight and colour.
- Use one smart screenshot picker for click-to-window or monitor selection and drag-to-region capture. Freeze the displayed frame until capture, save plain results under `Pictures/Screenshots`, copy them as PNG images, and expose annotation as a modifier variant of the same picker.
- Prefer **Maple Mono NF CN** for terminal and monospace UI; Geist Mono is an available secondary font.
- Favor rounded borders, small gaps, capsule or powerline-shaped status elements, restrained transparency, and background blur. Match shell popup radii to the compositor's normal window radius, and align screen-edge flyout offsets with its outer window gap.
- Round every shell surface on that one radius — panels, buttons, list rows, and menu bar entries alike — and derive shape, spacing, and the hover, press, selection, and semantic tints from a shared token block instead of per-widget literals. Reserve pill and circular shapes for switches, meters, and status dots.
- Decide a size, weight, tracking, space, control height, elevation, edge, or duration once, in that block, and name the step for the role it plays rather than for its value. A new control picks a step; it does not introduce a value. A glyph normally takes the step above the text beside it, and a meter or a rounded end is rounded on its own height rather than on a literal that outgrows the bar it is drawn in. Center a font glyph in a fixed box by its visible ink bounds, since icon glyphs can draw outside the advance width QML centers by default.
- Spend the accent on state, not on chrome. Report the pointer in neutral light and reserve the accent for what a surface is actually saying: pressed, selected, on. Treat that neutral hover as a wash over a filled control's resting material rather than as a translucent replacement; otherwise its animation flashes through the visible state and settles back into the panel. A panel outlined in accent, a hover that lights every entry lavender, and an outline around a chip whose fill already states its selection are all the accent spent on decoration, and it stops carrying meaning once everything wears it.
- Frame a surface in two parts rather than one: a grounding ring in the palette's darkest ink cuts it out of the wallpaper, and a hairline of light inside it — brightest along the top, held clear of the corner arcs — keeps the cut reading as glass. A card takes the same edge one step quieter. Nothing is separated by a heavier fill where an edge will do.
- Introduce a panel with its mark set in a small tinted well rather than loose on the material, and let the well carry the weight so the glyph inside it can take a step down.
- Carry hierarchy in weight instead of bolding every label: DemiBold for a title or an active label, Medium for a quiet uppercase rule, Light for the large numerals a card leads with, and nothing set to plain bold. Track the uppercase section rules widely enough that a run of capitals reads as a rule rather than as a shouted word, keep them a step smaller than the text they introduce, and leave everything else untracked at one size and one colour wherever they appear.
- Build depth out of translucency rather than out of greys, and out of one ink rather than several. A card is a tint of the panel's own material, a list row a lighter tint again, a track or well is cut back to that ink, and one opaque step is reserved for a control that overlaps a row whose own fill moves under the pointer. Lift a card with a hairline rather than with a heavier fill. An unset switch or knob is a well in the surface, not a grey pill, so the only lit control in a row is the one that is on.
- Assemble a panel from shared components — its header, its section rules, its meters, its card edges — rather than rebuilding those parts per panel. Hand-assembled headers drift apart on glyph size, row height and baseline, and the vertical nudges that follow are the evidence, not the fix.
- Let a panel's height fall out of its content. A counted constant and the viewport arithmetic beside it drift apart, and the panel then clips its last row, reserves space nothing draws in, or does both at once. Where a height must be stated, build it from the tokens the panel is actually laid out with.
- Give shell chrome a textured, Zen-like material rather than flat fills: translucent surfaces the compositor blurs, a quiet vertical wash that gathers light at the top and settles into ink at the bottom, and a faint grain film over the content. Generate a texture asset at build time from a seeded script instead of committing an image, and make it film rather than snow: a fine octave averaged from several samples, clumped by a coarse one, on a tile wide enough that its repeat never announces itself.
- Grade a filled meter along its length instead of laying it down flat, and let the track it runs in read as a well with its own hairline.
- Give a menu bar entry a hit target that spans the bar to the screen edge while the visible pill stays inset, and highlight an open panel only on the bar it was opened from.
- Open a menu bar panel directly below the entry that opened it, with their horizontal centers aligned. Clamp the panel only when it reaches a screen side, using the compositor's outer window gap as the inset.
- Keep the menu bar the darkest and quietest surface in the shell, since it is the one that is always on screen: ink the wallpaper shows through, closed at the bottom with a hairline rather than a coloured rule, and no light along the top edge, where there is no wallpaper for that edge to be lit against. Give its workspaces three steps and light only the top one — accent for the workspace in front of the user, a tint of the strip's own light for one holding windows, and barely anything for an empty one.
- Round images, album art, and video previews on the same radius as the surface holding them.
- Keep scroll indicators thin and show them only when content exceeds the viewport and the pointer is over the popup, including in views where scrolling is normally expected. Keep a thumb visible until an active drag ends. Give every scrollable one shared spring and keep it tight: an overshoot that drifts reads as lag rather than as feedback that the list has ended.
- Introduce every panel with its own glyph.
- Derive a list the system already knows — timezones, devices, locales — from the system's own data rather than curating entries by hand.
- Keep a popup on the screen that opened it until it closes. Track the output at open time rather than the compositor's focused monitor, which would otherwise move an open surface the moment the pointer crossed a screen edge.
- Keep shell popouts, application launchers, tooltips, and hover feedback immediate. Reserve animation for small in-surface state changes rather than moving whole windows, layer surfaces, or translucent cards. Avoid startup noise, tips, changelog clutter, and ornamental motion that slows interaction. Give every hover and press tint the same short duration rather than fading some and snapping others, and keep that duration and the slightly longer one a travelling control uses in the token block with everything else.
- Show the pointer cursor on everything that answers a click, including menu bar entries, and only on those. Half a strip that responds and half that does not reads as decoration.
- Hold a surface's hover state for as long as the pointer is anywhere on that surface, including while it rests on a control the surface carries or on one sitting just outside the area that reports it. Every module on a surface answers the pointer the same way: one card staying dark while its neighbours light, or a control that reports nothing because it is already on, reads as a broken hitbox rather than as restraint. A card that goes cold under its own dismiss button, or a row that drops as the pointer reaches the button its hover just revealed, reads as a flicker and as a hitbox that does not match the shape being pointed at.
- Suppress a tooltip because the thing it names is behind an open surface, never because a surface is open. A tip on a control inside a panel is reachable only while that panel is up, so the menu bar's guard has to exempt it.
- Acknowledge asynchronous popup actions immediately without changing control geometry. Animate an in-place refresh glyph only while work is active, and briefly show completion or failure when the resulting state is not self-evident.
- Give related usage totals one shared time-range selector. Token counts and their estimated cost must cover the same day, rolling week, rolling month, or available-history period.
- Balance compactness with legibility: show useful state, icons, previews, and status, but remove redundant labels and inactive widgets.
- Label a status entry or panel with the stable identity of the thing it tracks. Use the application's or module's name rather than its current window title or an implementation-specific synonym, and let changing detail live in the entry's value or tooltip. Read now playing as `<title> · <artist>`.
- Give a month only its own days. A calendar section that borrows the days on either side to square itself into a block prints another month's dates under this month's heading, so leave those cells empty and let a month that needs four rows be four rows tall. Keep the ISO week number beside each row it belongs to.
- Use 24-hour time, ISO-style dates, and Europe/Berlin when a timezone must be chosen. Show seconds only for local time in the expanded clock, keep other zones at minute precision, and use persistent pins instead of a temporary preview. Keep the menu bar clock compact. The desktop language is primarily English; preserve the German keyboard layout where host input is concerned.

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
| Nix distribution | Determinate Nix everywhere this flake reaches: both hosts through its NixOS and nix-darwin modules, and every Home Manager and portable evaluation through its Home Manager module, so no user profile carries a Nix of its own. This flake's own nixpkgs stays the `nixpkgs` registry pin. Configure Nix through `nix.settings` on NixOS and `determinateNix.customSettings` on Darwin |
| Browser | Zen as the primary experience; Brave as a compatible secondary browser |
| Logitech peripherals | OpenLogi on Linux; Logi Options+ on macOS |
| App launchers | Seele's native unified menu with Vicinae on Linux and Raycast on macOS |

Use Vicinae's standard launcher layout; Seele Shell carries the compact native desktop UI. Prefer explicit package paths in generated services and bindings when execution must be independent of `PATH`. Preserve interoperability rather than forcing every tool into one implementation.

## Development experience

- Favor two-space indentation where the language or formatter permits it, relative line numbers, smart-case search, and smart indentation.
- Provide rich language intelligence: LSP, inlay hints, Treesitter, formatting, snippets, diagnostics, and contextual documentation.
- Keep completion user-controlled: offer strong suggestions and fuzzy matching without silently accepting the first item.
- Integrate navigation boundaries. Pane movement should flow between Neovim and tmux instead of trapping focus.
- Prefer previews and structured dashboards for changes, pull requests, files, and sessions.
- Optimize routine VCS flow around rebasing, autosquash/autostash, pruning, rerere, signed work, and small composable Jujutsu operations.
- Treat a configured program as reachable off the managed hosts. When a tool's worth is its configuration rather than the machine around it, publish it as a portable flake output so one `nix run` carries it to a borrowed or remote machine. Shells, editors, terminals, pickers, multiplexers, and VCS tooling qualify; the compositor, greeter, desktop shell, and anything whose state belongs to the machine do not. A portable wrapper keeps the foreign machine's own configuration intact and confines whatever it writes to a directory of its own.

## Privacy and security defaults

- Disable telemetry, analytics, studies, and install tracking when the option exists and functionality does not depend on them.
- Prefer tracking protection, content blocking, privacy-oriented search, and role-separated browser containers/spaces.
- Delegate secrets to an existing password manager or hardware-backed mechanism; preserve SSH signing, YubiKey, Touch ID, and trust prompts.
- Reuse a successful graphical login to unlock the user's existing secret store when its password matches the login password; a non-Plasma session must still start the PAM handoff bridge rather than prompting again later.
- Reach for the mechanism a graphical prompt can actually hook rather than trying to give a terminal tool a GUI: `sudo` runs its own terminal PAM conversation and cannot be made to use a desktop agent, while systemd's `run0` authorizes through polkit and inherits whatever agent is installed. Leave `sudo` in place beside it rather than aliasing. Scope the interactive `sudo` → `run0` abbreviation to the managed Linux profile; Darwin and portable Fish keep `sudo`.
- Split hardware-token PAM surfaces by what they guard: entering a session (`login`, and so `greetd`, plus Seele Lock) requires the token *in addition to* the password, while approving an action (`sudo`, `polkit-1`) accepts a touch *instead of* it. Never leave a token prompt silent — a surface that blocks for a touch without saying so reads as broken.
- Pin the relying-party identity of a hardware token (pam_u2f `origin`/`appid`, and the equivalent elsewhere) to the flake rather than letting it default to the hostname; a machine rename otherwise orphans every enrolled credential, and one enrollment should follow the user to every host in the flake. Treat that value as enrolled-key state, not configuration.
- Order a blocking hardware-token module against how the client drives PAM, not by habit. Seele Lock collects the password through Quickshell's asynchronous PAM bridge and then renders the blocking token cue, so keep the password first and the touch after. A greetd greeter collects credentials up front, while synchronous terminal conversations such as `login` and `sudo` can tolerate either order.
- Model incoming SSH as one exclusive `off`/`tailscale`/`ssh` selector. `off` must leave no SSH listener, `tailscale` accepts connections through tailnet policy, and `ssh` uses ordinary OpenSSH with public-key authentication only. Disable the unselected path before enabling the selected one.
- Treat application self-update controls in the context of declarative package management: updates should come through the managed system rather than bypass it.

## Resolve the characteristic tensions

- **Compact vs informative:** keep actionable state visible; make secondary detail contextual or on demand.
- **Automation vs safety:** automate reversible routine work; confirm trust, destructive changes, and activation.
- **Polish vs noise:** use color, icons, rounded geometry, and motion for hierarchy; keep startup and idle surfaces quiet.
- **Cross-platform vs uniform:** reproduce intent and muscle memory, not necessarily the same application.

When a completed change clearly establishes, reverses, or corrects one of these preferences, update this skill from active evidence. Do not promote a single host-specific necessity into a general preference.
