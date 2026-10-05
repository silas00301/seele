# Configuration inspector

Run `seele-inspect fish`, `seele-inspect shortcut`, or
`nix run .#inspect -- package --json` on a managed host. The shared Home Manager
feature installs the helper and a generated catalog on nerv and asuka. It includes
Home Manager and system `programs.*.enable` / `services.*.enable` settings, direct
home/system package inclusions and their source locations. On nerv it also indexes
literal one-line `hl.bind` shortcuts with descriptions. Complex generated bindings
are outside this first projection; the existing Keybindings picker remains the
complete runtime keyboard readout.

The header says **Declared configuration**: this catalog is published during
activation, not sampled from running processes. An unactivated edit does not change
it. Enabled is the effective Nix boolean, not proof a service is healthy or running.
A package entry explains direct inclusion and preserves every recorded definition
source. It does not invent a reason for transitive closure members; use
`nix why-depends` deliberately for those.

Search requires all words and matches keys, kinds and displayed values. JSON rows
make the same readout available to other local tools. Results show numbered source
files. `seele-inspect --open home.programs.fish.enable --source 1` opens that exact
recorded file; add `--repo /path/to/seele` to open the corresponding local checkout
file instead. Only this flake's own module paths can be remapped. Upstream files
remain their recorded store paths and cannot be mistaken for a local module.

Only selected nonsecret metadata enters the catalog: booleans, direct package
names, shortcut descriptions and source paths. It never serializes arbitrary option
values, password/token fields or executable shortcut arguments. Sources without a
recorded absolute path are left unavailable. Inspection does not fetch inputs,
snapshot Jujutsu, build or activate a configuration. Opening a source is explicit;
the editor retains responsibility for any later write.

The native package runs `projects/config-tools/tests/inspect.py` against synthetic
catalogs and a fake editor. Native search, source-root and traversal tests live in
`inspect.rs`. Nix evaluation and the generated catalog must also be checked on each
native host before activation, especially the provenance data from deferred modules.
