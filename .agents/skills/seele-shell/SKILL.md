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

## Draw from the shell's design tokens

`projects/shell/shell.qml` opens with the shell's whole visual vocabulary, and
every surface below it reads from that block rather than deciding for itself:

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
  accent. A state that is not hover never borrows `hoverColor`.
- **Motion** — `durationFast` for an in-surface tint, `durationNormal` for a
  control that travels.

Assemble a surface from the shared components rather than repeating their
parts: `PanelHeader` (glyph or `mark` in its accent well, title, optional
detail, trailing slot), `SectionLabel`, `MeterBar`, `CardEdge`, `PanelSurface`,
`SurfaceWash`, `SurfaceEdge`, `SurfaceGrain`, `SlimScrollBar`, `ControlSwitch`,
`RefreshGlyph`, `CenteredGlyph`, `HoverTip`, `BarItem`, `BarLabel`, `ControlTile`,
`ConnectivityRow`, `ControlLevel`, and `MediaButton`. A framed surface takes
all three of `SurfaceWash`, `SurfaceEdge` and `SurfaceGrain`, in that order:
the wash under the content, the edge and the film over it.

A `HoverTip` on a control inside a panel needs `inOverlay: true`; without it the
menu bar's guard hides the tip whenever the panel is open.

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

The helper verifies that the submodule is clean, commits only the parent gitlink through Git, imports that commit into Jujutsu, advances `main` to it when possible, and updates the `seele-shell` entry in `flake.lock`. Do not stage the parent gitlink manually.

Review the resulting parent state:

```sh
jj status
jj diff
```

Commit the refreshed lock and any intended companion parent changes with Jujutsu file selection so existing work stays separate:

```sh
jj commit flake.lock <companion-parent-paths> -m "Refresh Seele Shell"
jj bookmark set main -r @-
jj git push --bookmark main
```

Omit `<companion-parent-paths>` when the shell change has no parent-side code. Keep unrelated paths in the working-copy commit.

## Prove the parent consumes the new revision

The gitlink and lock must both match the pushed submodule commit:

```sh
shell_rev="$(jj -R seele-shell log -r @- --no-graph -T commit_id)"
gitlink_rev="$(git ls-tree main -- seele-shell | awk '$1 == "160000" { print $3 }')"
lock_rev="$(jq -r '.nodes["seele-shell"].locked.rev' flake.lock)"
test "$shell_rev" = "$gitlink_rev"
test "$shell_rev" = "$lock_rev"
```

Then run the parent Seele validation workflow. At minimum, format the parent, evaluate the flake and native host, build `packages.<system>.seele-shell`, and build the native host closure. A rebuild-ready result has a clean pushed submodule, matching gitlink and lock revisions, passing submodule and parent builds, and a pushed parent bookmark.

Activation is separate. Run `nh os switch`, `nh darwin switch`, or an equivalent activation command only when the user explicitly asks to change the live machine.
