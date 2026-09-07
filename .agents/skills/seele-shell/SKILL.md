---
name: seele-shell
description: Develop Seele Shell and carry its Jujutsu-managed submodule changes through validation, commit, push, parent gitlink refresh, lock update, and rebuild-ready verification. Use for changes under seele-shell/ or when shell work must become consumable by the parent Seele flake.
---

# Seele Shell workflow

Treat `seele-shell/` and its parent as separate Jujutsu repositories. Use `jj -R seele-shell` for submodule history, and keep Git's staging area out of both workflows. The repository-owned parent helper uses Git internally because Jujutsu does not snapshot submodule gitlinks.

## Protect both working copies

Run from the parent root:

```sh
jj status
jj -R seele-shell status
jj -R seele-shell log -r '@ | @- | main | main@origin' --no-graph
```

Record pre-existing changes in each repository. Keep unrelated paths out of commits. A detached submodule HEAD is normal.

## Work and validate inside the submodule

Keep UI and runtime behavior in `seele-shell/`. Put parent-side service, package, theme, or Home Manager integration in the parent flake.

`nerv` runs a Lua Hyprland configuration, so anything in `projects/tools/` that
reaches the compositor issues one `hl.dsp` call — `hl.dsp.window.close({ window
= "address:0x…" })`, not `dispatch closewindow address:0x…`. hyprctl exits zero
on the Lua error the legacy form raises, so a wrong call is invisible until the
action is tried by hand.

## Keep frozen URI picking responsive

`seele-shellctl uris` reaches `UriPicker.qml` and one `seele-shell-uris` layer
surface per output. The separate Rust `seele-uri-worker` owns concurrent Grim
PPM captures and a bounded pool of warmed Tesseract engines from nixpkgs. Its
Rust grayscale and 1.5× enlargement pass preserves small URI punctuation. Keep
OCR off the QML thread and display the exact pixels being recognized. Use
local adaptive thresholds for dim address-bar text beside bright browser chrome.
An empty scan or failure releases captures and keyboard focus immediately;
a separate click-through status surface shows the result for five seconds. Capture
open shell panels and toasts before covering them, and preserve panel state
across dismissal. Stream results into the retained ListModel, keep numbers
stable across outputs, and
wait for the complete number set before auto-opening a typed number. Enter
resolves an exact numeric prefix; never use a timeout to guess user intent.

The same pool runs nixpkgs ZBar on whole outputs for QR codes and barcodes.
Keep ordinary OCR active alongside code detection. Code payloads use exact
decoded text, without OCR prose cleanup. Number selects a URI or copies other
text; Ctrl + number copies either and stays latched through multi-digit input.
Show code text below its box, or above when the output has insufficient room.
Pass clipboard text through stdin to wl-copy and render it as plain text.

Images are private runtime files and are removed on cancellation, EOF, errors,
and graceful termination. Guard messages by generation so an old scan cannot
reopen a dismissed overlay. Boxes are normalized within each captured output;
never use desktop-global coordinates or assume every monitor shares a scale.
`tests/uri-picker.sh` exercises real OCR, capture identity, strip boundaries,
and cleanup, while `tests/uri-picker.js` covers selection and badge geometry.

## Notification interactions

`NotificationStore.qml` owns the desktop notification service through
Quickshell, with lifecycle and presentation helpers in `notifications.js`.
The parent disables mako; hardware status workers never publish notification
or DND fields. `seele-shellctl notification <action>` and `notification-status`
reach the native store over IPC, and `seele-control` keeps matching commands.

Ordinary toasts default to 30 seconds, pause while hovered, and retire without
closing the inbox entry. Respect positive sender timeouts for the toast;
critical, explicitly non-expiring, and user-pinned toasts stay until hidden.
Resident means actions do not close the notification, independently of its
toast timeout. Transient notifications skip the inbox and history and expire
through the protocol. Only explicit dismissals enter the bounded 24-hour
history. Keep DND, history, timestamps, and pins across QML reloads through
`PersistentProperties`; never persist message text or codes to disk.

Both views group by desktop entry (falling back to app name), show overlapping
cards, and expand independently. Toasts have individual card material with no
shared backdrop. A toast close hides it; panel dismissal closes it. Named
actions, including Reply, invoke the sender's app interface. Verification codes
copy explicitly without dismissal. Preserve urgency, local images, progress,
markup, links, action icons, and replacement IDs/tags. Only advertise capabilities
that are rendered. At the pinned Quickshell revision, `expireTimeout` exposes
raw D-Bus milliseconds despite its seconds documentation.

`tests/notifications.js` exercises the state machine and grouping;
`tests/notification-server.sh` runs a windowless Quickshell on a private D-Bus
session to check the real API and production IPC handlers during the package
build. `tests/control-actions.sh` checks command and clipboard failures.

## Preserve status model identity

`projects/shell/SystemState.qml` owns the status fields and their startup
values. Feed snapshots and optimistic patches through `apply()` so each field
notifies independently and unchanged JSON branches retain their identity.
Replacing the whole state object makes unrelated bindings rerun and rebuilds
list delegates. Add new backend status fields to this component as well.
`tests/system-state.sh` checks signal counts, delegate reuse, and unchanged
rendered pixels; both `test-shell` and the main package build run it.

Performance work keeps rendering components, visual tokens, and motion timing
unchanged unless the user asks to change their appearance or pace.

The shell reads field patches from `seele-control watch-status`. Guard callback
side effects on the presence of their field: an audio update carries neither
headphones nor notifications. `projects/tools/src/live.rs` owns D-Bus listener
reconnects, a buffered PipeWire monitor, and the five-second ancillary refresh.
NetworkManager and BlueZ signals trigger source-specific probes. Notifications
and DND belong exclusively to the native QML store. Explicit stdin requests
return complete source fields even when unchanged so optimistic controls can
settle. Keep that acknowledgement separate from unsolicited deltas.
`projects/tools/tests/live.rs` runs against a private bus and mock probes;
`tests/status-patches.js` exercises the shell's actual partial-update callback.

`seele-clock watch` caches static timezone metadata for the current database,
year, and locale, but computes times, offsets, and pins on every `refresh` line.
Both workers exit on stdin EOF. Clock's timezone conversions remain in its own
single-threaded process because libc's `TZ` state is process-global.

## Standalone Notes and dictation

`projects/notes/` is a separate desktop app, not a shell panel. The `notes`
output provides `seele-notes` and `seele-notes-store`; the parent exports
`seele-notes`. Reopen its existing process through IPC. The shellctl/Vicinae
launch must detach so a launcher's command timeout cannot kill the app.

Keep notes and WAV memos in the private XDG data library. Text uses atomic JSON
writes and request/version acknowledgements; retain newer drafts after stale
responses or worker reconnection. A failed save must block a pending move to
Trash. Trash remains recoverable. The recorder owns its `parecord` child and
must finalize on Stop, EOF, and SIGTERM, reap the child, and prevent a recording
note from being trashed. Playback lives in a separately loaded QtMultimedia
component. Build both `default` and `notes` when shared QML changes.

Run `tests/notes.py` with the raw `seele-notes-store` helper, plus
`tests/notes.js` and `tests/notes-store.js`. The latter exercises production QML
save callbacks. `tests/dictation.py` checks the native audio bridge against a
fragmented/reconnecting Voxtype socket. Dictation follows the daemon's JSON
status and native audio frames; never open a second capture just for levels.
Keep the overlay on its starting output and leave focus and pointer input alone.

Clock sources merge both tzdata city tables and its backward aliases. Refresh
clock rows at minute boundaries and panel opening, using one snapshot for time,
date, and offset. Calendar models depend on the date, not the seconds tick.
Keep ISO week arithmetic in UTC and local clock display in the system timezone.

## Draw from the shell's design tokens

`projects/shared/Theme.qml` owns the shell and Notes visual vocabulary. Both
entrypoints inherit it, and shared components receive it as `theme`. The shell
keeps thin inline aliases for its existing instances. Every surface reads from
that block rather than deciding for itself:

- **Type** — `textMicro` through `textHero`. Steps are named for the role they
  play. A glyph normally takes the step above the text beside it; a glyph set
  in a well takes the step below, because the well carries the weight.
- **Weight** — `weightLight`, `weightRegular`, `weightMedium`, `weightStrong`.
  Nothing sets `font.bold`.
- **Tracking** — `trackingLabel`, for uppercase section rules only.
- **Space and size** — `spaceTight` through `spaceLarge`, `cardPadding`, and the
  three control heights `chipHeight`, `controlHeight`, `rowHeight`, beside the
  existing `radius`, `panelMargin`, `panelSpacing`, and `panelHeaderHeight`.
- **Elevation** — `panelColor`, `cardColor`, `rowColor`, `wellColor`,
  `floatColor`, `cardBorder`, and `separatorColor`. Depth is built out of one
  ink, `crust`: chrome is cut out of the wallpaper with it and wells are cut
  back to it.
- **Edges** — `panelBorder` grounds a surface in that ink, `edgeLight` is the
  hairline of light inside it, and `edgeCrown` is the brighter line along the
  top. No edge carries the accent.
- **Interaction** — `hoverColor` is the neutral light wash that reports the
  pointer. Apply it directly only over transparency; a filled control uses
  `hoveredColor(<resting fill>)` so the wash remains visibly composited over
  its material. `pressColor`, `selectedColor` and `activeTint` report state in
  accent. A state that is not hover never borrows `hoverColor`. An animated
  fill that rests on nothing rests on `clearColor`, or on `clearDanger` where
  the state it fades from is red — never on `transparent`, because Qt
  interpolates a colour channel by channel and `transparent` is black, so a
  tint animated against it is dragged through grey at both ends of the fade.
- **Motion** — `durationFast` for an in-surface tint, `durationNormal` for a
  control that travels.

Assemble a surface from the shared components rather than repeating their
parts: `PanelHeader` (glyph or `mark` in its accent well, title, optional
detail, trailing slot), `SectionLabel`, `SectionRule` (that label with the
group's live summary at the far end and, where the group folds, the chevron and
the click target that fold it), `MeterBar`, `CardEdge`, `PanelSurface`,
`SurfaceWash`, `SurfaceEdge`, `SurfaceGrain`, `SlimScrollBar`, `ControlSwitch`,
`RefreshGlyph`, `CenteredGlyph`, `HoverTip`, `BarItem`, `BarLabel`, `ControlTile`,
`ConnectivityRow`, `ControlLevel`, `MediaButton`, and `MediaBody`. A framed surface takes
all three of `SurfaceWash`, `SurfaceEdge` and `SurfaceGrain`, in that order:
the wash under the content, the edge and the film over it.

A `HoverTip` on a control inside a panel needs `inOverlay: true`; without it the
menu bar's guard hides the tip whenever the panel is open.

A card, row or tile that reports the pointer takes that state from a
`HoverHandler` on the surface itself, never from a covering
`MouseArea.containsMouse`. Qt hands a hover event to one item, so a control the
surface carries takes it away from the area underneath and the surface goes
cold under a pointer that is still on it. Keep the `MouseArea` for the click
and the press — including where it is deliberately inset, as the Tailscale
card's is to leave its switch alone — and ask the handler whether the pointer
is there. The control doing the stealing is often not written inline: the
Control Center's audio card is covered by two `ControlLevel` instantiations,
each a hover area, and a `ModuleDragArea` is a `MouseArea` under another name,
so grepping for `MouseArea` misses both.

Two more ways a surface goes quiet under the pointer. A fill that branches on
state before hover — `active ? accent : hovered ? ...` — can never report a
pointer on an active control; lay the neutral hover wash over the state as its
own child instead of making it another branch. And a highlight inset inside its
row leaves a dead line above and below itself, which the spacing between rows
widens into a band; a row highlight takes the row's full height.

The Control Center's media module and the Now Playing panel it opens draw the
same `MediaBody` at the same `mediaBodyHeight`, so there is one place to change
what a track looks like. The card wraps it in a module surface with hover and a
`ModuleDragArea`; the panel puts it under a `PanelHeader`. Neither arranges the
parts itself. Their player comes from one root selection. The panel exposes that
selection through `MediaPlayerPicker` when more than one resumable player is on
the bus, and the Control Center follows it.

Hover cannot be verified by warping the cursor with `hl.dsp.cursor.move`: the
compositor delivers a pointer event only when the warp crosses into a different
surface, so consecutive moves inside one panel leave the shell reading the first
position. Bounce off an unrelated surface between samples, then diff `grim`
captures against a pointer-away baseline.

The AI cockpit is a readout. Its session row is one card with a cell per
harness — a lit dot and a name, beating only while that session works or waits,
a well in the card while nothing runs — and no cell answers a click, so none of
them takes the pointer cursor. `agentIndicators()` is what the row draws: the
launchers CodexBar reports, plus any harness that published lifecycle state
without one. A lit cell answers the pointer and focuses its
session through `seele-control agent-focus`, which walks the record's pid up
through `/proc` to the terminal holding it; a finished record has no window
left, so only a running session takes the pointer cursor. Launching lives in
`seele-agent`, `seele-shellctl agent`, the `launchAgent` IPC method, and the
menu bar entry's right click, not in the panel.

`AgentMark` draws a harness or provider as its own vendored SVG, rasterized
well above the size it is drawn at because the OpenAI knot loses its loops in a
24px raster squeezed into the menu bar. `agentMark()` maps an id to a file and
returns an empty string for anything unknown, which falls back to
`agentBadge()`'s two letters. The marks are flat: state belongs to the beating
bar under a badge and to the tier colour on a capacity's number, not to the
mark. Adding one means the SVG beside `shell.qml`, an `install` line and the
`installCheckPhase` mark loop in `package.nix`, and an entry in `agentMark()`.

Size a panel from its content — `implicitHeight: <content>.implicitHeight +
root.panelMargin * 2`, with the content column anchored left, right and top.
Where a panel must state a height, build it from the tokens rather than a
counted constant, and derive any viewport inside it from the same terms.

`projects/lock/`, `projects/greeter/`, and `projects/polkit/` are separate
clients that mirror the subset of these tokens they use. Keep a value they
share identical to the shell's, and drop a token from their block when nothing
in that client reads it.

A palette colour a client reads has to arrive from the parent as well: the
generated `theme.json` in `modules/features/programs/seele-shell.nix` and
`seele-greeter.nix` carries the named palette entries, and a client that reads
a new one needs both the key there and the assignment in its own `FileView`.

The grain film is generated at build time by `seele-tools grain`, in
`projects/tools/src/grain.rs`. It is a seeded two-octave tile — fine noise
drawn as the mean of several samples, clumped by a coarse wrapping octave —
and both octaves wrap, so the tile stays seamless. Tune `grainOpacity` with it:
a finer film needs a little more of it to read at all.

Use the narrowest package build that contains the change:

```sh
cd seele-shell
nix build .#default --no-link --no-write-lock-file
nix build .#notes --no-link --no-write-lock-file
nix build .#greeter --no-link --no-write-lock-file
nix build .#lock --no-link --no-write-lock-file
nix build .#polkit --no-link --no-write-lock-file
```

The default package build compiles the Rust tools, runs `qmllint`, bundles the extensions, and runs the focused shell tests. Build every affected output when shared code changes. Use `nix develop -c test-shell` for a faster Rust and JavaScript loop, but finish with the relevant package build.

Inspect the submodule diff before crossing back into the parent:

```sh
jj -R seele-shell diff
jj -R seele-shell status
```

## Commit and push the submodule

Commit and push only when the user asked for a rebuild-ready result or otherwise authorized those history and remote changes.

Commit only the intended submodule paths. Jujutsu leaves every unselected change in the new working-copy commit:

```sh
jj -R seele-shell commit <paths> -m "<shell change>"
jj -R seele-shell status
```

Fetch the remote bookmark and inspect it against the new commit:

```sh
jj -R seele-shell git fetch --remote origin
jj -R seele-shell log -r 'main@origin | @-'
jj -R seele-shell log -r 'main@origin ~ ancestors(@-)' --no-graph
```

An empty result from the final command proves the push will be a fast-forward. If it prints a commit, rebase the local stack onto `main@origin` and resolve any conflicts before continuing:

```sh
jj -R seele-shell rebase -s 'roots(main@origin..@-)' -d main@origin
```

Move the local bookmark to the commit and push through Jujutsu's remote safety checks:

```sh
jj -R seele-shell bookmark set main -r @-
jj -R seele-shell git push --remote origin --bookmark main
jj -R seele-shell status
```

The parent helper requires a clean submodule, so leave the boundary here if unrelated submodule changes remain. Never discard or commit those changes just to satisfy the helper.

## Refresh the parent pointer

Return to the parent root and run:

```sh
nix run .#update-submodule
```

The helper verifies that the submodule is clean, commits only the parent gitlink through Git, imports that commit into Jujutsu, advances `main` to it when possible, and refreshes the shell's transitive inputs in the parent lock. Do not stage the parent gitlink manually. The `seele-shell` input is a path inside the parent flake, so the gitlink pins its source revision and source-only shell updates leave `flake.lock` unchanged.

Review the resulting parent state:

```sh
jj status
jj diff
```

If the lock or companion parent code changed, commit only those paths before advancing and pushing `main`:

```sh
jj commit flake.lock <companion-parent-paths> -m "Refresh Seele Shell"
jj bookmark set main -r @-
jj git push --bookmark main
```

Omit `flake.lock` when the shell's transitive inputs did not change, and omit `<companion-parent-paths>` when there is no parent-side code. If neither changed, the helper's gitlink commit is ready to push. Keep unrelated paths in the working-copy commit.

## Prove the parent consumes the new revision

The gitlink must match the pushed submodule commit, and the lock must keep the relative path input:

```sh
shell_rev="$(jj -R seele-shell log -r @- --no-graph -T commit_id)"
gitlink_rev="$(git ls-tree main -- seele-shell | awk '$1 == "160000" { print $3 }')"
lock_path="$(jq -r '.nodes["seele-shell"].locked.path' flake.lock)"
test "$shell_rev" = "$gitlink_rev"
test "$lock_path" = "seele-shell"
```

Then run the parent Seele validation workflow. At minimum, format the parent, evaluate the flake and native host, build `packages.<system>.seele-shell`, and build the native host closure. A rebuild-ready result has a clean pushed submodule, a matching gitlink, the relative path lock with refreshed transitive inputs, passing submodule and parent builds, and a pushed parent bookmark.

Activation is separate. Run `nh os switch`, `nh darwin switch`, or an equivalent activation command only when the user explicitly asks to change the live machine.
