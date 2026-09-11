# Middle-click compatibility (SIL-49)

The `middle-click` Home Manager feature is active only on `nerv`. It sets
GTK 3 and GTK 4's `gtk-enable-primary-paste` to false in toolkit configuration
and the desktop settings schema. It locks Zen's `middlemouse.paste` and
`middlemouse.contentLoadURL` off and `general.autoScroll` on. Selection and
normal explicit clipboard actions remain available.

This is partial support. Zen owns its native target resolution, browser-link
middle-click behavior, autoscroll indicator, direction and cancellation. This
configuration does not replace these with Seele's requested vertical-only
indicator. GTK widgets that honor the setting stop pasting, but gain no
autoscroll. Qt, Seele's QML controls, Ghostty and other custom input handlers
have no global protection from this module. SIL-49 must stay open.

## Why the remaining work needs another input layer

Wayland's `wl_pointer` reports surface-local input, not a semantic child target
or whether a child scrolls. AT-SPI exposes named actions and key bindings, but
no standardized mapping from an action to a middle mouse button. Qt accessibility
can expose explicit scroll actions; these can support certified scroll targets,
but their existence does not certify an unrelated middle-button semantic action.
The current shared Seele Flickable and ListView controls do not publish that
contract either.

The inspected Hyprland Lua event bridge exposes keyboard observations; it does
not expose cancellable pointer-button/axis callbacks. Lua callbacks discard
return values. A global interceptor therefore needs a version-matched compositor
plugin or equivalent supported input layer, plus adapters that identify exact
semantic targets. A window class, hand cursor, or an ancestor scroll area is
not sufficient proof. Do not replay an unknown middle-click: it can paste.

A future implementation must consume unknown targets and cancellation events
at that input boundary, authorize replay only for a certified semantic action,
and address a certified scroll target without changing focus or pointer position.
It must also cancel on target invalidation and compositor/session changes.
Do not activate an untested plugin in the user's live session.

## Validation matrix

On the native host after an explicitly authorized activation:

| Surface | Check | Implemented expectation |
| --- | --- | --- |
| GTK 3 / GTK 4 entry | Select text elsewhere, middle-click the entry | No primary paste, if the widget honors GtkSettings |
| GTK scrolling background | Complete a middle click | No new autoscroll implementation |
| Zen page background | Complete a middle click, move away and return | Browser-native autoscroll and browser-native indicator |
| Zen link | Middle-click a real link | Browser-native open-in-new-tab behavior |
| Zen text field | Middle-click with primary selection set | No primary-selection paste |
| Zen empty page background | Middle-click with URL in primary selection | No navigation from selected URL |
| Ghostty, Qt, Seele | Repeat paste and autoscroll cases | Not implemented; do not claim global coverage |

The authoring machine has no Nix, graphical Hyprland session or toolkit test
runtimes. Nix formatting, evaluation and these interactive checks were not run.
There is no new custom state machine in this partial change, so no test fixture
pretends to verify the missing compositor or toolkit integration.

## Primary references

- [GTK 3 primary-paste setting](https://docs.gtk.org/gtk3/property.Settings.gtk-enable-primary-paste.html)
- [GTK 4 primary-paste setting](https://docs.gtk.org/gtk4/property.Settings.gtk-enable-primary-paste.html)
- [Firefox autoscroll target resolution](https://searchfox.org/firefox-main/source/toolkit/actors/AutoScrollChild.sys.mjs)
- [Wayland protocol model](https://wayland.freedesktop.org/docs/book/Protocol.html)
- [AT-SPI Action interface](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/iface.Action.html)
- [Qt accessibility actions](https://doc.qt.io/qt-6/qaccessibleactioninterface.html)
- [Hyprland Lua event bridge](https://github.com/hyprwm/Hyprland/blob/main/src/config/lua/LuaEventHandler.cpp)
- [Ghostty configuration reference](https://ghostty.org/docs/config/reference#copy-on-select) documents middle-click paste as always enabled, independent of copy-on-select.
