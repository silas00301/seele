---
name: seele-style
description: Use this to build new applications and shell elements matching the rest of the ui
---

# Seele's visual language

Seele draws in **Material 3 Expressive**: colour roles derived from the theme's palette,
Material's corner scale with shapes that change with state, tonal elevation instead of
translucency, state layers for the pointer, and spring motion. Every surface in the shell
is assembled from one vocabulary. A new control **picks a
token and reaches for a component**; it does not invent a value or rebuild a part. That
one law is what makes the shell look designed rather than accumulated, and it is the
thing to hold onto when a surface tempts you to write `height: 36` or a fifth hover
branch.

The words below are the vocabulary. Use them in code, in comments, and when reporting
work: **token**, **role**, **ramp**, **container**, **card**, **row**, **rule**,
**state layer**, **shape**, **spring**, **mark**, **meter**, **track**.

## Start from the block

`seele-shell/projects/shared/Theme.qml` holds the whole vocabulary — palette, colour
roles, type ramp, weights, spacing ramp, control heights, the shape scale, elevation,
state layers and springs. `Palette.js` derives the colour roles from the palette,
`Motion.js` samples the springs and `Shapes.js` holds the Expressive shape library.
**Read that block before drawing anything.** It is the source of truth for every value;
this skill is the source of truth for which one to pick. The shell and every standalone
Seele application root at `Shared.Theme`, so they all read the same block, and a user's
`theme.json` repaints all of them at once. On `nerv`, the theme-switching feature
links that file to the native switcher's saved Base16 projection; new surfaces must keep
consuming this shared entry point.

If a value you need is not in the block, you have found one of two things: a step you
should have picked, or a genuine gap in the vocabulary. Add the token to the block with
a comment naming the role it plays, then use it. Never leave the value at the call site.

## The ramps

A **ramp** is a named ladder of steps. Pick a step by the role it plays, not by the
number that lands nearest.

**Type** — `textMicro` → `textHero`. The names say the role: `textCaption` is row detail,
`textBody` a row title, `textLead` a card's own subject, `textTitle` a panel title,
`textDisplay` a hero numeral. Two rules decide glyph sizes: a glyph beside text takes the
step **above** that text, because an icon drawn at the same pixel size reads smaller than
a letter; a glyph set **in a shape or a container** takes the step below, because the
shape carries the weight.

**Weight** — `weightStrong` for a title, a subheader or an active label, `weightMedium`
for a button's label, `weightLight` only for large numerals that would otherwise read as
a wall, `weightRegular` for everything else. Nothing sets `font.bold`.

**Case** — sentence case everywhere, section rules included. Material's subheader is a
short label in the primary colour, so nothing is written in capitals or tracked out to
read as a rule.

**Space** — `spaceTight` → `spaceLarge` inside a card, `cardPadding` for a card's own
inset, `panelMargin` and `panelSpacing` for the panel.

**Control height** — `chipHeight` (28), `controlHeight` (34), `rowHeight` (40). This is
Material at the desktop's density. A chip, a button and a list row each take one; `detailRowHeight` (52) is the row that leads with a
mark and sets a caption under its title. A card or tile still sizes to what it holds.
`knobSize` is the round control a connectivity row, a Control Center tile and a level lead
with, and a tile without a knob keeps that column for its glyph so titles line up.

**Media geometry** — `mediaPanelWidth` is the width that lets the shared media block
carry art, text and transport without squeezing them. `trackTarget` is the taller pointer
strip around a thin interactive timeline; `trackHead` is the width of the upright handle
Material's slider draws, held `trackHandleGap` clear of the track on either side.
`levelHeight` is the large slider a module's own level is drawn as.

**Shape** — the corner scale is Material's: `shapeExtraSmall` (4), `shapeSmall` (8),
`shapeMedium` (12), `shapeLarge` (16), `shapeLargeIncreased` (20) and `shapeExtraLarge`
(28), and a full pill at any height is `height / 2`. Pick by role: `radiusPanel` for a floating panel,
`radius` for a card, `radiusRow` for a row, a field or a menu item, `radiusSmall` for a
part inside an already-rounded part. A control the pointer aims at — a button, an icon
button, a bar entry, a knob — is a full pill or circle (`height / 2`).

**Motion** — springs, never curves picked by eye. `springFastSpatial` over
`durationFastSpatial` for anything that travels, grows or changes shape; it overshoots a
little and settles. `springDefaultSpatial` over `durationDefaultSpatial` for a surface
that unfolds — a fold growing, a group opening. `durationFast` (the fast effects spring)
for a tint or a fade, which never overshoots. Pass a spring as
`easing.type: Easing.BezierSpline; easing.bezierCurve: root.springFastSpatial`. Only
in-surface state changes animate. Never animate a whole window or layer surface.

## Roles and elevation

Material names a colour by what it does. `Palette.js` derives every role from the eleven
palette colours a theme carries, so the switcher's presets, the lock and Notes repaint
together: `primary` is the accent; `primaryContainer`, `secondaryContainer`,
`errorContainer`, `successContainer` and `warningContainer` are tones of a palette colour
over the base; each container has its content colour, written `textOn…` because QML
reserves the `on` prefix for signal handlers (`textOnPrimary`,
`textOnSecondaryContainer`, …). `text` and `subtext` are Material's `onSurface` and
`onSurfaceVariant`; `outline` and `outlineVariant` are the quiet lines. Never pair a
container with a content colour from another role: text on `primary` is
`textOnPrimary`, never `crust`, because on a light scheme the palette's `crust` is
light.

**Elevation is tonal.** The surface ramp `surfaceContainerLowest` → `surfaceContainerLow`
→ `surfaceContainer` → `surfaceContainerHigh` → `surfaceContainerHighest` steps towards
the text: lighter on a dark scheme, darker on a light one. The legacy role tokens sit on
it: `panelColor` (container) → `cardColor` (high) → `rowColor` and `wellColor`
(highest). Every container is solid. Depth comes from the step, never from translucency,
a gradient wash, a lit edge or a texture.

**Edges** belong only to floating surfaces. `PanelSurface` draws `panelBorder`, a
hairline of the outline variant, because a layer surface casts no shadow to lift it off
the window below. Cards, rows and controls take no stroke.

Hold a container's content and its state colour together: a selected row sits in
`selectedColor` (the secondary container) with `textOnSecondaryContainer`; an active
tile in `activeTint` (the primary container) with `textOnPrimaryContainer`; the one
thing that is *on* — a switch, the play button, the workspace in front — in `primary`
with `textOnPrimary`.

A tint laid **over** content — the URI picker's region over frozen pixels, the bar's drop
highlight over its entries — is the primary colour at a state layer's alpha, never a
container: containers are opaque and would hide what they mark.

## Colour

**Spend the accent on state, not on chrome.** The pointer is reported by a neutral state
layer; the primary colour and its containers are reserved for what a surface is actually
saying — selected, active, on. A panel outlined in the accent, a hover that lights every
row, and an outline around a chip whose fill already states its selection are all the
accent spent on decoration, and it stops meaning anything once everything wears it.

Semantic colour is graded rather than binary. A capacity meter runs `primary` while the
window is comfortable, `yellow` once about a third is left, `red` once it is nearly
spent. A destructive control is the one place hover itself is semantic: dismiss and shut
down sit in the error container and say what they will do through their content
colour, and `HoverWash`'s `tint` takes that content colour.

An animated fill that rests on nothing rests on that tint at zero alpha — `clearColor`,
`clearDanger`, or `alpha(tint, 0)` — never on `transparent`. Qt interpolates channel by
channel and `transparent` is black, so a tint animated against it is dragged through grey
at both ends and the control reads as a smudge lifting off the surface.

## The parts

Reach for these rather than rebuilding them. Hand-assembled parts drift apart on glyph
size, row height and baseline, and the vertical nudges that follow are the evidence, not
the fix.

They live in two places. `seele-shell/projects/shared/*.qml` is the portable set: each
one takes `required property var theme` and is usable by the shell *and* by Seele Notes
or any later standalone application. `shell.qml` aliases each as
`component X: Shared.X { theme: root }` so shell code writes `X { }` unqualified, and
defines the shell-only parts inline beside those aliases. **A part a second surface
could want belongs in `shared/`**, with its reasoning in the file rather than at the
alias — put it there when you add it, not after the second caller appears.

| Part | What it is for |
| --- | --- |
| `PanelSurface` | A floating panel's container: the extra-large corner, `panelColor`, and the outline-variant hairline. |
| `PanelHeader` | A panel's mark in an Expressive shape on the primary container, title, optional detail, trailing slot. |
| `MaterialShape` | One of Material 3 Expressive's shapes (`cookie9`, `softBurst`, `clover4`, `pill`, …) filled in a colour, morphing on the spatial spring when `shape` changes. The mark a header or an empty state leads with. |
| `SectionRule` | Material's subheader: a sentence-case label in the primary colour that opens a group, the group's live summary at the far end, a trailing slot for whatever control governs the group, and a chevron where the group folds. |
| `SectionLabel` | The bare subheader, for a caption that is not opening a group. |
| `DeviceListCard` | A card sized to the list inside it. |
| `SegmentWell` + `Segment` / `SegmentChoice` | Material's connected button group: exclusive choices side by side, the ends fully round and the inner corners small, the chosen one in the secondary container with its inner corners rounded too. The group tells each choice whether it opens or closes the row; a choice passes `fill` only to acknowledge a result for a moment. |
| `ActionButton` | A one-shot action: a pill in the secondary container, `primary` when `selected`, the error container when `danger`. It pinches to the small corner while held. |
| `IconButton` | The container behind an icon action: round at rest, squared towards the medium corner while `active`, pinched while `pressed`. An action whose state is not the accent's passes its own `tint`. |
| `GlyphButton` | A complete icon action on `IconButton`, with centred glyph, keyboard activation, accessible name and a plain tooltip. |
| `HoverWash` | The state layer: the content's own colour at 8% under the pointer and 10% while `pressed`, laid over whatever the control already says. It follows its parent's corners one by one. |
| `ControlSwitch` | Material's switch: an outlined track with a small handle when off, the primary track with a grown handle and a check when on, the loading indicator in the handle while `busy`. |
| `MeterBar` | Every filled track in the shell — capacity, usage, battery, volume, a day's temperature span — as Expressive's linear progress: the filled part and the rest of the track as separate pills with a gap, and a stop dot at the end. `from` starts the fill partway along for a span; `wavy` with `flowing` turns the filled part into the moving wave a playing track's timeline draws. |
| `LevelTrack` | The drawing of a level the pointer sets, as Expressive's large slider: fill, upright handle and rest with gaps, the level named inside the track in whichever ink each part needs. `DeviceSlider`, the Audio levels and a player's volume all draw it; the owner keeps the input. |
| `DeviceSlider` | A device level on `LevelTrack`, with Qt's Slider keyboard and accessibility. `spectrum` draws a colour range. |
| `RefreshGlyph` | Asynchronous work in place: the refresh glyph at rest, the loading indicator while `spinning`. |
| `LoadingIndicator` | Expressive's loading indicator: seven shapes morphing into one another as it turns. Needs no theme, so the auth clients draw it too. |
| `HoverTip` / `PlainTooltip` | Material's plain tooltip on the inverse surface. Inside a panel `HoverTip` needs `inOverlay: true`. |
| `FocusRing` | Where the keyboard is: a secondary-coloured outline held `focusGap` clear of the control on its own corners. Pass `gap: 0` inside a parent that clips, `baseRadius` where the parent is not a Rectangle. |
| `PanelPicker` | The shell's dropdown: a chip on the highest surface step behind the rule's fold arrow, opening Material's menu with the current row in the secondary container. Shell-only for now, because the callers are both in `shell.qml`. |
| `CenteredGlyph` | A font glyph centred by its visible ink rather than its advance width. |
| `BarLabel` | A menu bar label carrying arbitrary text, baseline-anchored to the primary font. |
| `SeeleListView` / `SeeleFlickable` | Every scrollable, so one spring governs them all. |
| `ChoiceBox` | A bounded native ComboBox as Material's exposed dropdown: the filled field and a menu on the high surface step. |
| `HistoryChart` | Render-only bounded series: fixed recent window, shared scale and breaks for missing samples. |
| `SearchField` | The one input that filters a list: Material's search bar, a pill on the highest surface step outlined in the primary colour while it has the keyboard. |
| `ValueField` | A short editable value as Material's filled text field: the highest surface step closed by an active indicator that thickens into the primary colour on focus and turns to the error colour when `invalid`. |
| `EmptyState` | What a surface says when it has nothing to show: its mark in an Expressive shape, a sentence and a way out. |
| `StatusBanner` | A surface's own bad news on a card toned in its colour, carrying the actions that answer it. |
| `StatusChip` | A short state named in its own tint — GitHub priority, Maintenance urgency, a job, transfer or integration state, PR checks and review, notification urgency. Red for failure or act now, yellow for attention, green for done, primary for live work, overlay otherwise. Material's chip on the small corner, its container toned from its own colour, never a control; in a dense row it takes that row's height. |
| `SlimScrollBar` | The scroll indicator, shown only while the pointer is over the popup. |
| `RoundedSource` | An Image rounded through `MultiEffect` masking. A sender's picture or an account is an avatar, which Material draws as a circle. |
| `AgentMark` | A harness or vendor drawn as its own vendored SVG. |

The Control Center and media surfaces add `ControlTile`, `UtilityTile`, `ConnectivityRow`,
`ControlLevel`, `AudioLevelRow`, `ApplicationLevelRow`, `MediaBody`, `MediaButton` and
`MediaTimeline`. `ControlTile` is a module with state, half the grid wide, a title over a
detail line, drawn as Expressive's quick setting — a card on the large corner while
quiet, the primary container rounded into a pill while active; `UtilityTile` is a
quarter-wide launcher, a glyph over a short name, whose description lives in its tooltip
and whose only state is a corner reading and a fill toned in that reading's colour.
`ConnectivityRow` leads with a knob that is round while its radio is off and a
square-cornered primary knob while it is on. Every tile and knob pinches while it is
held. `ControlCenterGrid` lays them out with positioners, never counted offsets, and owns
arrow-key movement across everything in it that takes focus. A module
that lives in both the Control Center and its own panel draws the same body in both,
**and frames it the same way**: the panel puts the block on a card exactly as the
module does, so opening a module never unframes what was clicked.
A second level in the same panel takes the first one's anatomy a step down the ramp
rather than a shape of its own: `ApplicationLevelRow` is `AudioLevelRow` at
`rowHeight`, with the application's icon where the master row's glyph is, and both
pin their numeral to `levelValueWidth` so the tracks stacked under one another stay
comparable.

## Composing a surface

A panel is a stack of groups, and every group has the same shape:

1. A `SectionRule` opens it. The group's live summary goes at the far end of that rule;
   whatever switch governs the group rides on it rather than standing in a row above it.
2. The group's content sits in a **card** — `DeviceListCard` for a list, otherwise a
   `Rectangle` on `cardColor` with the `radius` corner, sized from its own content column.
3. Rows inside that card take `rowColor` on `radiusRow`, one step up the ramp from the
   card.

What the panel is *about* goes in its header's `detail` line, never on a loose line under
the title. Every panel is introduced by its own mark.

Choose the control by what the user is doing:

- **An exclusive choice** — a usage range, a noise mode, which path SSH takes, which of
  two views is being read — is a connected button group, `SegmentWell` of `Segment`s or
  `SegmentChoice`s. Never several separate outlined boxes side by side: the shared
  outer pill and the small inner corners are what make the group read as one control.
  The group is for a choice worth seeing all of at once. A choice that is rarely made,
  or whose set can shrink to one, is a dropdown on the group's rule instead — a group
  that spends a row on five segments, or draws a single segment because the set has
  one member, is the shape telling you it was the wrong one.
- **A one-shot action** is a button. Actions are not a choice among each other.
- **A persistent on/off state** is a `ControlSwitch` beside the title or on the group's
  rule.
- **A hand-off** to the panel that owns the detail is the row itself, with the knob or
  switch keeping the state. Split it the way macOS does.

**Let a panel's height fall out of its content**: `implicitHeight:
<content>.implicitHeight + root.panelMargin * 2`, with the content column anchored left,
right and top. A counted constant and the viewport arithmetic beside it drift apart, and
the panel then clips its last row, reserves space nothing draws in, or does both. Where a
height must be stated — a scroll viewport over hundreds of rows — build it from the
parts the panel is actually laid out with, measured rather than counted.

## The menu bar

The bar is the one surface always on screen, so it is the lowest and quietest step of the
surface ramp, with no divider under it, as Material draws a top app bar that nothing has
scrolled beneath. Its workspaces are Expressive's page indicator and take three steps,
only the top one lit — a wide `primary` pill for the workspace in front of the user, the
secondary container for one holding windows, `surfaceContainerHigh` for an empty one —
and the pill travels on the spatial spring.

A `BarItem` spans the bar's full height so a pointer thrown at the screen edge still
lands on it, while only the visible pill is inset. An open panel puts just the entry on
the screen it was opened from in the secondary container.

A panel opens directly below the entry that opened it, with their horizontal centres
aligned, and is clamped only when it reaches a screen side, using the compositor's outer
window gap as the inset. A popup stays on the screen that opened it: record the output at
open time rather than tracking the focused monitor, which would move an open surface the
moment the pointer crossed a screen edge.

Name a vendor or product on the bar with its own **mark** rather than its spelled-out
name — the strip is always on screen and a mark says the same thing in a third of the
width. Vendor marks are flat SVGs beside `shell.qml`, and they stay flat: state belongs
to whatever is already carrying it, the beating bar under a badge or the tier colour on a
number beside the mark. Keep a two-letter badge as the fallback so a vendor without a
mark still reads.

## Interaction

**The pointer is reported by a state layer — `HoverWash` — laid over the control, never
by another branch of its fill.** A fill that tests its own state first —
`selected ? … : hovered ? …` — can never report a pointer on the control that is
selected, on, pinned or already running, which is the control the pointer is most often
aimed at. A press is the same layer at the pressed opacity, and on a control that
changes shape it is the shape too: buttons, knobs, tiles and segments pinch towards a
smaller corner while they are held. A momentary acknowledgement —
busy, complete, failed — may still outrank the resting fill, because it lasts a second
and then goes.

Hold a surface's hover for as long as the pointer is anywhere on that surface, including
while it rests on a control the surface carries. Take that state from a `HoverHandler` on
the surface itself, never from a covering `MouseArea.containsMouse`: Qt hands a hover
event to one item, so a control the surface carries takes it away from the area
underneath and the surface goes cold under a pointer that is still on it. The thief is
often not written inline — `ControlLevel` is a hover area, and a `ModuleDragArea` is a
`MouseArea` under another name.

A row highlight takes the row's **full height**. Inset inside its row it leaves a dead
line above and below itself, which the spacing between rows widens into a band the
pointer crosses on its way from one row to the next.

Show the pointer cursor on everything that answers a click and only on those. A control
that no longer acts should stop looking like one: no border of its own, no pointer
cursor, and the exact state in its tooltip.

Keep popouts, launchers, tooltips and hover feedback immediate. Reserve animation for
small in-surface state changes.

Acknowledge an asynchronous action immediately without changing the control's geometry:
animate a `RefreshGlyph` in place only while the work is live, and show completion or
failure briefly when the resulting state is not self-evident.

A group that opens — a stack of notifications, a fold — grows the item it is
already in rather than inserting rows around it. Inserting displaces everything
below and can carry the group out from under the pointer that just opened it;
growing in place keeps it where the click landed, and gives the height something
to animate on the default spatial spring. Clip the growing item so its content is
revealed rather than appearing.

A **readout** is not a control. Where a surface reports what something else is doing —
which sessions are running, which devices are connected — draw indicators rather than
buttons, and give them the pointer cursor only if the indicator actually acts on the
thing it reports.

## Traps

Each of these has been hit at least once. The symptom is what to watch for.

- **Hover after state.** Symptom: the selected row is the one row that stays cold.
  Cure: `HoverWash`.
- **`transparent` as a resting colour.** Symptom: a tint fades in through grey and reads
  as a smudge. Cure: `clearColor` / `alpha(tint, 0)`.
- **A counted constant.** Symptom: a panel clips its last row or reserves an empty band.
  Cure: measure the parts.
- **A glyph centred by its advance width.** Symptom: an icon sits off-centre in its box.
  Cure: `CenteredGlyph`.
- **An auto-sized label carrying arbitrary text.** Symptom: a menu bar entry sits off the
  line its neighbours are on, and the drift depends on the words. Cure: `BarLabel` —
  one glyph the primary font lacks pulls in a fallback with a taller line box.
- **A ragged numeric column.** Symptom: bars in a list stop being comparable because
  each one's right edge moves. Cure: pin the column's width.
- **A control labelled from its own state.** Symptom: everything left of a row's button
  shifts because `Unpin` is wider than `Pin`. Cure: measure the widest label with
  `TextMetrics` and give the control that width in every state.
- **A container laid over content.** Symptom: a highlight that used to tint what it
  marked now hides it. Roles are opaque. Cure: the primary colour at a state layer's
  alpha.
- **A content colour from another role.** Symptom: text on a filled control vanishes on
  a light theme. Cure: the matching `textOn…` role, never `crust` or `base`.
- **A property named like Material's `onPrimary`.** Symptom: the binding silently does
  nothing, because QML reads `on…` as a signal handler. Cure: the `textOn…` names.
- **A spring sampled finer than Qt allows.** Symptom: the shell aborts with heap
  corruption when an animation starts. Qt's `BezierSpline` easing overruns its storage
  past ten segments. Cure: the springs from `Motion.js`, which use eight.
- **A `Rectangle` asked to clip.** Symptom: content escapes the rounded corner. Cure:
  `ClippingRectangle`.
- **A tabbable control that draws nothing for focus.** Symptom: tab moves through a
  transport or picker and the panel never changes. Cure: `FocusRing`, with `gap: 0`
  inside a parent that clips.
- **A group that stays open to say it is empty.** Symptom: a card whose only content is
  a sentence about why the card has nothing in it, or the same "nothing here" written
  once per group. Cure: withdraw the rule and its content together, and let one
  `EmptyState` speak for the whole surface.
- **An anchored click area inside a `Column`.** Symptom: labels overlap because Qt disables the positioner. Put the labels in a nested column and its full-size click area beside it, inside an `Item` sized from the labels.
- **A panel following the focused monitor.** Symptom: an open surface jumps to another
  output when the pointer crosses a screen edge. Cure: record the output at open time.
- **A tooltip hidden because a panel is open.** Symptom: a control inside a panel never
  shows its tip. Cure: `inOverlay: true`.

Hover cannot be verified by warping the cursor with `hl.dsp.cursor.move`: the compositor
delivers a pointer event only when the warp crosses into a different surface. Bounce off
an unrelated surface between samples, then diff `grim` captures against a pointer-away
baseline.

## Beyond the shell

Seele Notes (`projects/notes/`) is a full application built from this vocabulary: it
imports `../shared` directly, roots at `Shared.Theme`, and is the reason a part worth
sharing goes in `shared/`. Its package copies shared QML components and their JavaScript together and
runs `qmllint` over the result, so a new shared component is picked up automatically and
a warning in one fails `nix build .#notes`. `SearchField`, `EmptyState` and
`StatusBanner` moved there when Notes needed them, because a query, a nothing-to-show
state and a surface's own bad news are not particular to one application.

An application that is not a panel still keeps the panel's shape. Notes leads with a
`PanelHeader` carrying no `detail` line — a header explaining what the window is for is
chrome that earns nothing after the first launch — and puts every state that is not a
note into a `StatusBanner` above the split: the write that failed, the file that changed
underneath, the folder that cannot be written to. Each one carries its own way out.
`EmptyState` covers the rest: nothing here yet, nothing matches, the trash is empty. A
state without an action is a state the reader can do nothing about.

`projects/lock/`, `projects/greeter/` and `projects/polkit/` are separate clients that
mirror the subset of non-palette tokens they use. Their roots take fallback palette values,
JSON assignment and the Material roles (`roles: Palette.roles({...})`) from
`projects/shared/Palette.js`, and the lock and greeter draw the shared
`LoadingIndicator` with `Motion.js` and `Shapes.js`; each package copies exactly those
files into its own `shared/`. Never put a Catppuccin value, a second assignment loop or a
second role derivation back in those roots. Keep another shared
token identical to the shell's, and drop it when nothing in that client reads it. A palette
colour a client reads also has to arrive from the parent: the generated `theme.json` in
`modules/features/programs/seele-shell.nix` and `seele-greeter.nix` carries the named
entries, and a client reading a new one needs the key there; the shared palette assignment covers every declared palette
property. `tests/palette.js` and `tests/tst_palette.qml` preserve fallback and
Qt color/alpha behavior, including the main shell's existing wallpaper override, and pin
the role derivation on a dark and a light palette.

## Finish

Before reporting a surface done, account for **every control you drew**:

- Every size, weight, space, radius, height, colour and duration is a token from the
  block. No literal survives at a call site.
- Every part that exists as a shared component is that component, not a rebuild of it,
  and a new part a second surface could want went into `projects/shared/`.
- Every group is a rule over a card; every exclusive choice is a connected button group;
  every one-shot action is a button; every container is paired with its own content
  colour.
- Every control that answers a click reports the pointer through a `HoverWash` and shows
  the pointer cursor; every control that does not, does neither.
- The panel's height falls out of its content.
- The surface renders. `nix build .#default` inside `seele-shell` runs `qmllint` and the
  focused tests; a visual change is worth a render before it is worth a claim.

Then follow the [`seele-shell` skill](../seele-shell/SKILL.md) for validation, the
submodule commit flow and the parent gitlink.
