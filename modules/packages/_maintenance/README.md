# Maintenance findings

The `maintenance` Home Manager feature on nerv starts a private user service with
`%t/seele-maintenance.sock` (0600). `seele-maintenance request` reads one bounded
JSON request on stdin and returns one JSON response. Only same-uid clients are
accepted. System Health polls this shared metadata contract, never source probes.

Configured sources register action IDs before publishing. `publish` takes
`source` and `finding`: stable `key`, safe `title`, `explanation`, `details`, one of
`now/soon/eventually/informational`, `lifecycle` (`ongoing` or `notice`), registered
`actions`, and optional `diagnostic` (at most16KiB). `resolve` takes source/key.
The built-in publishers provide complete source snapshots: absent keys resolve
only after a successful full probe. Failures preserve existing conditions.

`list` returns active/snoozed/history rows, count, highest urgency and source check
errors. Mutations require `id` and the current `revision`: `snooze` with seconds
(60 to30days), `unsnooze`, `done` (notice only), `action` with registered action ID,
or `analyze`. Disruptive actions require `confirmed:true`. The socket is a
same-user contract, not an authorization boundary between the user's processes.
No command strings or caller-supplied process arguments are accepted.

Findings retain identity across recurrence. Unchanged snapshots neither advance
revision nor repeat notifications. Only new/materially changed Now/Soon findings
notify; urgency escalation removes snooze. Active metadata survives restarts;
resolved metadata and bounded typed action outcomes expire after seven days.
Publishers must supply curated summaries, never raw logs or credentials. Defensive
redaction and explicit persistence projections add another boundary. Diagnostic
bundles and AI output are memory-only and absent from persisted state. A restart
requires fresh publication before Analyze becomes available again.

Analysis sends only supplied metadata and diagnostics to `seele-codex` on explicit
request. The output schema restricts repair proposals to registered action IDs.
No proposal executes automatically. Changed findings mark previous analysis stale,
and stale proposals cannot be invoked. The UI requires a separate confirmation
for every proposed repair. Opening logs is an explicit local action and does not
supply those logs to AI.

## Source policy

`seele.maintenance` is declarative per host. Sources can be individually disabled.

- `systemd`: failed units from system or user manager; logs use the exact unit.
- `backups.items`: configured unit, scope, age threshold and optional success
  marker. A backup-owned marker is recommended for freshness across reboots;
  otherwise only systemd's current recorded successful completion is available.
- `disk`: configured paths, available blocks/inodes, default85% warning/95% critical.
- `flake`: daily `nix flake check --no-build --no-write-lock-file` on the configured
  checkout. This is evaluation checking, not a full host build or activation.
- `certificates.items`: local PEM files with default30/7day warning/critical windows.
- `inputs.items`: critical names and maximum pin ages (default nixpkgs,30days).
  Old pins are compared with the public GitHub/GitLab original reference using
  `nix flake metadata --no-write-lock-file`. Deliberately pinned original revisions
  remain pinned; unsupported references/follows produce a check error and retain
  existing findings. The helper never edits lock files or updates configuration.

Backups/certificates default to no items because no such systems are configured
in this flake. Flake/input probes use the existing host Nix executable; the package
does not install another Nix. No check activates a system or repairs automatically.

Run `test_model.py`, `test_server.py`, and `test_publishers.py` with Python3 plus
jsonschema. Run `node seele-shell/tests/maintenance.js
seele-shell/projects/shell/MaintenanceStore.qml`. Package checks run these same
backend suites; shell checks run the QML-method suite. Native Nix and compositor
validation remain required before deployment.
