---
name: seele-style
description: Use this to build new applications and shell elements matching the rest of the ui
---

# Seele's visual language

Every surface in the shell is assembled from one vocabulary. A new control **picks a
token and reaches for a component**; it does not invent a value or rebuild a part. That
one law is what makes the shell look designed rather than accumulated, and it is the
thing to hold onto when a surface tempts you to write `height: 36` or a fifth hover
branch.

The words below are the vocabulary. Use them in code, in comments, and when reporting
work: **token**, **ramp**, **rule**, **card**, **row**, **well**, **wash**, **mark**,
**meter**, **edge**, **grain**.

## Start from the block

`seele-shell/projects/shared/Theme.qml` holds the whole vocabulary — palette, type ramp,
weights, spacing ramp, control heights, elevation, edges, interaction tints, motion.
**Read that block before drawing anything.** It is the source of truth for every value;
this skill is the source of truth for which one to pick. The shell and every standalone
Seele application root at `Shared.Theme`, so they all read the same block, and a user's
`theme.json` repaints all of them at once.

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
a letter; a glyph set **in a well** takes the step below, because the well carries the
weight.

**Weight** — `weightStrong` for a title or an active label, `weightMedium` for a quiet
uppercase rule, `weightLight` only for large numerals that would otherwise read as a
wall, `weightRegular` for everything else. Nothing sets `font.bold`.

**Tracking** — `trackingLabel`, on uppercase section rules and nowhere else. A run of
capitals at ordinary spacing reads as a shouted word; spread far enough apart it reads as
a rule.

**Space** — `spaceTight` → `spaceLarge` inside a card, `cardPadding` for a card's own
inset, `panelMargin` and `panelSpacing` for the panel.

**Control height** — `chipHeight` (28), `controlHeight` (34), `rowHeight` (40). A chip, a
button and a list row each take one. A card or tile still sizes to what it holds.

**Motion** — `durationFast` for an in-surface tint, `durationNormal` for a control that
travels. Only in-surface state changes animate. Never animate a whole window, layer
surface or translucent card.

## Material and depth

Depth is built out of translucency and one ink, never out of a stack of greys. `crust` is
that ink: chrome is cut out of the wallpaper with it and wells are cut back to it.

The **elevation ramp** is `panelColor` → `cardColor` → `rowColor`, with `wellColor` cut
below all three and `floatColor` reserved for a control overlapping a row whose own fill
moves under the pointer. A card is a tint of the panel's material; a row inside that card
is a lighter tint again; a track or an unset switch is a well.

**Edges** come in two parts and never carry the accent. `panelBorder` grounds a surface
in the ink and cuts it out of the wallpaper; `edgeLight` is the hairline of light inside
it, `edgeCrown` the brighter line along the top where light would actually land. A card
takes the same edge one step quieter through `CardEdge`. Lift a card with a hairline, not
with a heavier fill.

A framed surface takes all three of `SurfaceWash`, `SurfaceEdge` and `SurfaceGrain`, in
that order: the wash under the content, the edge and the grain film over it. The grain
tile is generated at build time by `seele-tools grain`; it is never committed.

Round every surface on `radius` — the same 8px Hyprland rounds windows with — and use
`radiusSmall` only for a part inside an already-rounded part. Reserve pill and circular
shapes for switches, meters and status dots. A meter or a rounded end rounds on its own
height, never on a literal.

## Colour

**Spend the accent on state, not on chrome.** The pointer is reported in neutral light;
the accent is reserved for what a surface is actually saying — pressed, selected, on. A
panel outlined in lavender, a hover that lights every row, and an outline around a chip
whose fill already states its selection are all the accent spent on decoration, and it
stops meaning anything once everything wears it.

Semantic colour is graded rather than binary. A capacity meter runs `accent` while the
window is comfortable, `yellow` once about a third is left, `red` once it is nearly
spent. A destructive control is the one place hover itself is semantic: dismiss and shut
down say what they will do while the pointer is on them, through `HoverWash`'s `tint`.

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
| `PanelSurface` | A panel's material, edge, wash and grain in one. |
| `PanelHeader` | A panel's mark in its accent well, title, optional detail, trailing slot. |
| `SectionRule` | The uppercase rule that opens a group, with the group's live summary at the far end, a trailing slot for whatever control governs the group, and a chevron where the group folds. |
| `SectionLabel` | The bare uppercase label, for a caption that is not opening a group. |
| `CardEdge` | The hairline that lifts a card off the panel behind it. |
| `DeviceListCard` | A card sized to the list inside it. |
| `SegmentWell` + `Segment` | A set of exclusive choices as one well with the chosen one lit. |
| `IconButton` | The square that holds one glyph and answers a click. |
| `HoverWash` | The neutral light that reports the pointer, laid over whatever the control already says. |
| `ControlSwitch` | A persistent on/off state. Off is a well, not a grey pill. |
| `MeterBar` | Every filled track in the shell — capacity, usage, battery, volume. Graded along its length, running in a well with its own hairline. |
| `RefreshGlyph` | An in-place spinner for asynchronous work. |
| `HoverTip` | A tooltip. Inside a panel it needs `inOverlay: true`. |
| `CenteredGlyph` | A font glyph centred by its visible ink rather than its advance width. |
| `BarLabel` | A menu bar label carrying arbitrary text, baseline-anchored to the primary font. |
| `SeeleListView` / `SeeleFlickable` | Every scrollable, so one spring governs them all. |
| `SlimScrollBar` | The scroll indicator, shown only while the pointer is over the popup. |
| `RoundedSource` | An Image rounded on the shell's radius through `MultiEffect` masking. |
| `AgentMark` | A harness or vendor drawn as its own vendored SVG. |

The Control Center and media surfaces add `ControlTile`, `ConnectivityRow`,
`ControlLevel`, `AudioLevelRow`, `MediaBody`, `MediaButton` and `MediaTimeline`. A module
that lives in both the Control Center and its own panel draws the same body in both.

## Composing a surface

A panel is a stack of groups, and every group has the same shape:

1. A `SectionRule` opens it. The group's live summary goes at the far end of that rule;
   whatever switch governs the group rides on it rather than standing in a row above it.
2. The group's content sits in a **card** — `DeviceListCard` for a list, otherwise a
   `Rectangle` on `cardColor` with a `CardEdge`, sized from its own content column.
3. Rows inside that card take `rowColor`, one step up the ramp from the card.

What the panel is *about* goes in its header's `detail` line, never on a loose line under
the title. Every panel is introduced by its own mark.

Choose the control by what the user is doing:

- **An exclusive choice** — a usage range, a noise mode, which path SSH takes, which of
  two views is being read — is a `SegmentWell` of `Segment`s. Never several outlined
  boxes side by side: an outline around every alternative says what the fill of the one
  that is on already says, and the well is what makes the group read as one control.
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

The bar is the one surface always on screen, so it is the darkest and quietest: ink the
wallpaper shows through, closed at the bottom with a hairline rather than a coloured
rule, and no light along the top edge, where there is no wallpaper for that edge to be
lit against. Its workspaces take three steps and only the top one is lit — accent for the
workspace in front of the user, a tint of the strip's own light for one holding windows,
barely anything for an empty one.

A `BarItem` spans the bar's full height so a pointer thrown at the screen edge still
lands on it, while only the visible pill is inset. An open panel highlights just the
entry on the screen it was opened from.

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

**The pointer is reported by a `HoverWash` laid over the control, never by another branch
of its fill.** A fill that tests its own state first — `selected ? … : hovered ? …` — can
never report a pointer on the control that is selected, on, pinned or already running,
which is the control the pointer is most often aimed at. A momentary acknowledgement —
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
to animate over `durationNormal`. Clip the growing item so its content is
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
- **A tiled image on a rounded corner.** Symptom: the grain film squares off the arc.
  Cure: `SurfaceGrain`'s `inset`.
- **A `Rectangle` asked to clip.** Symptom: content escapes the rounded corner. Cure:
  `ClippingRectangle`.
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
sharing goes in `shared/`. Its package copies `projects/shared/*.qml` wholesale and
runs `qmllint` over the result, so a new shared component is picked up automatically and
a warning in one fails `nix build .#notes`.

`projects/lock/`, `projects/greeter/` and `projects/polkit/` are separate clients that
mirror the subset of non-palette tokens they use. Their roots take fallback palette values
and JSON assignment from `projects/shared/Palette.js`, copied into each package; never put
a Catppuccin value or a second assignment loop back in those roots. Keep another shared
token identical to the shell's, and drop it when nothing in that client reads it. A palette
colour a client reads also has to arrive from the parent: the generated `theme.json` in
`modules/features/programs/seele-shell.nix` and `seele-greeter.nix` carries the named
entries, and a client reading a new one needs both the key there and the assignment in
its own `FileView`.

## Finish

Before reporting a surface done, account for **every control you drew**:

- Every size, weight, space, radius, height, colour and duration is a token from the
  block. No literal survives at a call site.
- Every part that exists as a shared component is that component, not a rebuild of it,
  and a new part a second surface could want went into `projects/shared/`.
- Every group is a rule over a card; every exclusive choice is a well; every one-shot
  action is a button.
- Every control that answers a click reports the pointer through a `HoverWash` and shows
  the pointer cursor; every control that does not, does neither.
- The panel's height falls out of its content.
- The surface renders. `nix build .#default` inside `seele-shell` runs `qmllint` and the
  focused tests; a visual change is worth a render before it is worth a claim.

Then follow the [`seele-shell` skill](../seele-shell/SKILL.md) for validation, the
submodule commit flow and the parent gitlink.
