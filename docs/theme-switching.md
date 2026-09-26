# Seele Themes

On `nerv`, press **Super + Ctrl + Shift + T** for the shell's theme switcher: a
carousel floating in the middle of the focused output that closes nothing
already open. The Control Center's **Themes** tile sets light, dark or auto, and
opens the Themes panel for the rest. **Seele Themes** in Vicinae is the same
catalog from the launcher.

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
picks between them.

The switcher shows every preset, light and dark side by side, with the one on
screen large in the middle, drawn as a small desktop in its own colours — the
bar, a terminal with tmux's status line, a notification and a switch in its
accent — its neighbours as slices on either side and its name beneath. Left and
right (or Tab) switch the desktop at once, so the shell repainting around the
switcher is the preview, and a held key is coalesced so only the preset it stops
on is applied. A preset chosen there becomes the theme for its own mode and
switches to that mode: choosing Rosé Pine Dawn makes it the light theme and turns
the desktop light, and the dark theme stays what it was. Enter keeps and closes;
Escape puts the mode and both themes back as they were when the switcher
opened. Clicking a neighbour chooses it, and clicking the centre keeps it.

The Control Center's **Themes** tile names the theme on screen, and its round
knob shows **Light**, **Dark** or **Auto** and steps to the next. The rest of the
tile opens the Themes panel, which holds the same three choices; with Auto, when
it switches; and the theme each mode wears. **Use current** gives the preset on
screen to either mode, which is how light mode wears a dark preset, and
**Browse themes** opens the switcher over the panel.

**Auto** changes the mode by itself. **Set times** switches at two times of day,
editable in the panel (light from 07:00 and dark from 19:00 by default, the hours
the night light warms the screen at). **Sunrise, sunset** switches at sunrise and
sunset, reckoned from the system timezone's reference city in the tz database —
Berlin for `nerv` — so no location is asked for or stored; a timezone without a
city cannot follow the sun. A line in the panel says what the schedule does
next. The schedule acts only when a boundary passes, so a mode chosen by hand
holds until the next sunrise, sunset or fixed time, and a boundary missed while
the machine slept is caught up when it wakes. Choosing Light or Dark in the
panel turns Auto off. The `seele-theme-auto` user service runs the schedule in
the graphical session.

The launcher applies the theme for the mode on screen. It shows the applied
theme first, groups the rest by light and dark, and describes each palette's
roles beside what a switch reaches. No surface publishes anything itself: each
runs `seele-theme`, and the shell reads the applied theme and the preferences
from the files that helper publishes, so a change made in any place, or by the
schedule, is seen in the others.

`seele-theme list` returns the catalog, the current ID, both slots, the mode and
the schedule as JSON. `current` returns the selected ID. `set catppuccin-latte`
fills the slot of the mode on screen; `pick rose-pine-dawn` fills the slot of
its own mode and switches to that mode; `slot light rose-pine-dawn` fills either
slot; `mode dark` switches mode; `auto sun`, `auto schedule 07:00 19:00` and
`auto off` set the schedule; `reset` returns both slots, the mode and the
schedule to the flake's defaults. `init` refreshes generated files during Home
Manager activation while preserving the saved choices, and migrates an earlier
single selection into its own mode's slot.

| Surface | When colors change |
| --- | --- |
| Seele Shell, notifications, Notes, lock and polkit | Live through the shared theme file |
| Hyprland borders, shadows, groups and background | Live; also loaded with compositor configuration |
| Vicinae | Live through its theme command |
| Ghostty | Live through SIGUSR2 for same-user Nix Ghostty processes, including scratchpads |
| Neovim | Live through a file watcher, with a focus/startup fallback |
| Fish | At the next prompt |
| tmux | Live for the default server; also loaded when reading its configuration |
| Spicetify | Live through its packaged extension and a read-only loopback palette feed; restart Spotify once after the first rebuild to load the extension |
| GTK 3/4, GtkSourceView and Qt/Kvantum | New applications; existing windows may need reopening |
| KDE color schemes | Live through `plasma-apply-colorscheme` |
| X resources | Live through `xrdb`; existing X clients may need reopening |
| Zen Browser | Restart Zen after switching to load its selected chrome/content CSS |

This is a user-session feature. The boot screen, greeter, cursor, browser page
content and independently themed tools retain their configured appearance.
Wallpaper and font choices stay unchanged. `asuka` and portable applications
keep their declarative themes.

`modules/features/themes/_theme-switching/presets.json` selects schemes from
the pinned `base16-schemes` package. Its adjacent Nix helper evaluates the
upstream Stylix NixVim and Vicinae targets for every preset: Neovim receives
the generated `mini.base16` palette, and Vicinae receives the generated TOML.
The runtime projects that same palette into Seele and the other app includes.
For the targets enabled on `nerv`, the catalog also carries each preset's
Stylix-generated GTK, GtkSourceView, Qt/Kvantum, KDE, Spicetify and Zen assets.
The helper publishes one complete private generation and Home Manager links
the target files to it. KDE's named schemes come from those assets so its own
activation command can switch between preset IDs. The Spicetify extension
reads only the current ID and Base16 palette from `127.0.0.1:48725`; the
endpoint accepts no changes or Spotify account data.
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
existing `seele-shell/theme.json` path through a managed symlink. The one new
user service serves the public palette to Spicetify on loopback. No new inputs,
Python runtime or mutable edits to Home Manager files are used.

The native contract, transactional publication and fixtures are documented in
[`projects/config-tools/README.md`](../seele-shell/projects/config-tools/README.md).
The launcher fixture is `seele-shell/tests/vicinae-themes.cjs`, the shell
store and production wiring are covered by `seele-shell/tests/themes.js`, and
`seele-shell/tests/tst_themes.qml` renders the production switcher and Themes
panel in QtTest, failing on any Qt warning. Ordering,
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
