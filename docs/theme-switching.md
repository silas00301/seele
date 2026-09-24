# Seele Themes

On `nerv`, press **Super + Ctrl + Shift + T**, or open the Control Center's
**Themes** module, for the shell's own picker. **Seele Themes** in Vicinae is the
same catalog from the launcher. Search the curated presets, look at their
previews, and press Enter to apply one. The catalog includes 13 presets:

- Catppuccin: Mocha, Macchiato, Frappé and Latte.
- Rosé Pine: original, Moon and Dawn.
- Flexoki: Dark and Light.
- Gruvbox: Dark and Light, both medium contrast.
- Nord and Everforest (dark).

The configured flavor remains the initial choice. Selecting a theme needs no
rebuild, privileges or network access.

The shell panel leads with a small desktop drawn in the highlighted preset — its
bar, a focused terminal with coloured output, a notification and an accent
slider — which follows the arrow keys and the pointer, so a theme is seen before
it is applied. Below it each family is one row and each variant one tile, drawn
as a sample of itself: its name in its own text colour on its own background.
Search and an All/Dark/Light filter take tiles out without regrouping the rest.
The launcher shows the applied theme first, groups the rest by light and dark,
and describes each palette's roles beside what a switch reaches. Applying is one
request at a time, and
neither surface publishes anything itself: both run `seele-theme`, and the shell
panel reads the applied theme from the selection that helper publishes, so a
theme chosen in either place is marked in the other. The shell repaints itself
while its picker is open, because the panel is drawn with the same palette it is
choosing from.

`seele-theme list` returns the catalog and current ID as JSON. `current` returns
the selected ID, `set catppuccin-latte` changes it, and `reset` returns to the
flake's configured default. `init` refreshes generated files during Home Manager
activation while preserving the saved selection.

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
panel's store and production wiring are covered by `seele-shell/tests/themes.js`,
and `seele-shell/tests/tst_themes.qml` renders the production panel in QtTest,
failing on any Qt warning.
Family grouping, search, arrow-key movement, what the preview shows and every
failure sentence belong to `seele-shell/projects/qml-core/src/themes.rs` and are
tested there.
Run `lua tests/theme-editor.lua modules/packages/_nixvim/theme.lua` to verify
that the editor initializer leaves other hosts' remaining configuration running
and applies only complete, valid palettes through its watcher callback.
`checks.<system>.theme-presets` on Linux exercises every actual Stylix-generated
preset against the native switcher and checks launcher/editor palette parity.

Native validation should additionally exercise repeated dark/light changes with
an open Notes window, a notification, a lock screen, a running editor, and
Ghostty, then activate Home Manager and verify the selection persists. Full Nix
and live desktop checks require the native host; standalone tests do not prove
those integrations render or evaluate successfully.
