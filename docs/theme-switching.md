# Seele Themes

On `nerv`, press **Super + Ctrl + Shift + T**, or open the Control Center's
**Themes** module, for the shell's own picker: a carousel floating in the middle
of the focused output that closes nothing already open. **Seele Themes** in
Vicinae is the same catalog from the launcher.

The catalog includes 13 presets:

- Catppuccin: Mocha, Macchiato, Frappé and Latte.
- Rosé Pine: original, Moon and Dawn.
- Flexoki: Dark and Light.
- Gruvbox: Dark and Light, both medium contrast.
- Nord and Everforest (dark).

The configured Catppuccin flavor is the initial dark theme, and its family's
light variant, Catppuccin Latte, the initial light theme. Selecting a theme or a
mode needs no rebuild, privileges or network access.

The desktop keeps two presets, a light theme and a dark theme, and a mode that
picks between them. Any preset may fill either slot.

The carousel shows the preset on screen large in the middle, drawn as a small
desktop in its own colours — the bar, a terminal with tmux's status line, a
notification and a switch in its accent — with its neighbours as slices on
either side and its name beneath. The **Light / Dark** toggle chooses which slot
the carousel edits, and is also the desktop's mode. The carousel offers that
mode's presets until **Show all** opens it to every preset. Left and right (or
Tab) move and switch the desktop at once, so the shell repainting around the
picker is the preview, and a held key is coalesced so only the preset it stops
on is applied. Up switches to light and Down to dark; typing filters; Enter
keeps and closes; Escape first clears a filter, then puts the mode and both
slots back as they were when the carousel opened. Clicking a neighbour chooses
it, and clicking the centre keeps it.

**Auto** changes the mode by itself. **Times** switches at two times of day,
editable in place (light from 07:00 and dark from 19:00 by default, the hours
the night light warms the screen at). **Sun** switches at sunrise and sunset,
reckoned from the system timezone's reference city in the tz database — Berlin
for `nerv` — so no location is asked for or stored; a timezone without a city
offers no Sun. A line under the carousel says what the schedule does next. The
schedule acts only when a boundary passes, so a mode chosen by hand holds until
the next sunrise, sunset or fixed time, and a boundary missed while the machine
slept is caught up when it wakes. The `seele-theme-auto` user service runs the
schedule in the graphical session.

The launcher applies the theme for the mode on screen. It shows the applied
theme first, groups the rest by light and dark, and describes each palette's
roles beside what a switch reaches. Neither surface publishes anything itself:
both run `seele-theme`, and the carousel reads the applied theme from the
selection that helper publishes, so a switch made in either place, or by the
schedule, is seen in the other.

`seele-theme list` returns the catalog, the current ID, both slots, the mode and
the schedule as JSON. `current` returns the selected ID. `set catppuccin-latte`
fills the slot of the mode on screen; `slot light rose-pine-dawn` fills either
slot; `mode dark` switches mode; `auto sun`, `auto schedule 07:00 19:00` and
`auto off` set the schedule; `reset` returns both slots, the mode and the
schedule to the flake's defaults. `init` refreshes generated files during Home
Manager activation while preserving the saved choices, and migrates an earlier
single selection into its own mode's slot.

| Surface | When colors change |
| --- | --- |
| Seele Shell, notifications, Notes, lock and polkit | Live through the shared theme file |
| Hyprland borders | Live; also loaded with compositor configuration |
| Vicinae | Live through its theme command |
| Ghostty | Live for its systemd desktop service; other instances use Reload Configuration |
| Neovim | Live through a file watcher, with a focus/startup fallback |
| Fish | At the next prompt |
| tmux | Live for the default server; also loaded when reading its configuration |
| GTK 3/4 | New applications; existing applications may need reopening |

This is a user-session feature. The boot screen, greeter, cursor, Qt application
styles, browser content and other independently themed tools retain their
configured appearance. Wallpaper and font choices stay unchanged. `asuka` and
portable applications keep their declarative themes.

`modules/features/themes/_theme-switching/presets.json` selects schemes from
the pinned `base16-schemes` package. Its adjacent Nix helper evaluates the
upstream Stylix NixVim and Vicinae targets for every preset: Neovim receives
the generated `mini.base16` palette, and Vicinae receives the generated TOML.
The runtime projects that same palette into Seele and the other app includes.
Quiet text is held to a legibility floor in that projection, because schemes
disagree about what Base16's dim foregrounds are: Catppuccin's Base16 file puts
its surface colours in `base04` and `base03`, which taken verbatim would drop
the shell's secondary text on the default theme from 7.4:1 to 2.5:1. `subtext`
and `overlay` keep the scheme's slot when it clears 4.5:1 and 3:1; otherwise
they blend the text colour over the background in Catppuccin's own proportions,
which reproduce Mocha's `subtext0` and `overlay0` exactly. The text colour is
`base05` unless a scheme files a grey there — Everforest's is its `gray1` — in
which case its own `base06` or `base07` is used. Only Everforest's text changes;
every preset's quiet roles clear the floor.
These assets are generated during the build; switching only selects local files.
The configured Catppuccin accent is retained for the Catppuccin presets.

To add another scheme, add its ID, display name and light/dark mode to
`presets.json`, then rebuild once to include it. No application-specific theme
name or plugin mapping is needed.

`modules/features/themes/theme-switching.nix` declares the catalog and includes. It is
imported only by the `nerv` home profile. Home Manager owns those includes;
`seele-theme` owns only `$XDG_STATE_HOME/seele-theme`. The palette enters the
existing `seele-shell/theme.json` path through a managed symlink. No new inputs,
services, Python runtime or mutable edits to managed application files are used.

The native contract, transactional publication and fixtures are documented in
[`projects/config-tools/README.md`](../seele-shell/projects/config-tools/README.md).
The launcher fixture is `seele-shell/tests/vicinae-themes.cjs`, and the shell
carousel's store and production wiring are covered by
`seele-shell/tests/themes.js`, and `seele-shell/tests/tst_themes.qml` renders
the production panel in QtTest, failing on any Qt warning. Ordering, filtering,
movement and the schedule's sentence belong to
`seele-shell/projects/qml-core/src/themes.rs` and are tested there. The slots,
the mode and the schedule belong to `seele-shell/projects/config-tools`: its
`appearance.rs` tests pin sunrise and sunset to published times across seasons,
hemispheres and a polar day and night, and `tests/appearance.py` drives the real
helper through migration, both schedules, a hand-chosen mode holding until its
boundary, catch-up after a gap, and `follow` applying a boundary on its own. Run
`lua tests/theme-editor.lua modules/packages/_nixvim/theme.lua` to verify that
the editor initializer leaves other hosts' remaining configuration running and
applies only complete, valid palettes through its watcher callback.
`checks.<system>.theme-presets` on Linux exercises every actual Stylix-generated
preset against the native switcher and checks launcher/editor palette parity.

Native validation should additionally exercise repeated dark/light changes with
an open Notes window, a notification, a lock screen, a running editor, and
Ghostty, then activate Home Manager and verify the selection persists. Full Nix
and live desktop checks require the native host; standalone tests do not prove
those integrations render or evaluate successfully.
