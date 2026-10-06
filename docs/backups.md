# Encrypted backups and restore checks

`nerv` imports the `backups` feature, but `seele.backup.enable` is false until an
actual destination and private runtime credentials are provisioned. No repository
was supplied for SIL-28. This implementation is reviewable infrastructure, not a
claim that the machine already has successful backups. SIL-29 must remain blocked
until real destination restore tests pass, followed by its own VM and reboot tests.

The explicit initial path list covers the whole user's home and `/etc/machine-id`.
It keeps Downloads, notes, wallet and application state. Exclusions cover `.cache`,
Trash and rebuildable `node_modules`, `target` and `.direnv` directories below
Developer. Review that list before enabling; nothing infers durability from a
future persistence layout. Root-owned application state outside those paths needs
an explicit addition. The identity-file sample proves a real archived file can be
read, restored and compared; add a stable personal document or vault file to
`restoreSamples` to cover the data you particularly depend on.

Provision root-owned mode-0600 repository/password files under a root-owned
private directory outside `/nix/store` and `/home` (the restore sandbox hides
home). Use strings naming those files in the Nix options, never Nix path literals
or secret values. The repository file contains the destination, without tokens
embedded in its URL. An optional private `environmentFile` provides backend
credentials to systemd. Nothing imports any of these contents into Nix. The
native validator checks the deliberately configured references' type, ownership,
permissions, link count, size and parent-directory permissions before starting.

Initialize the destination deliberately using restic's `--repository-file` and
`--password-file` options. `initialize = false` prevents the timer from creating
an unintended repository when a destination changes. Then set, for example:

```nix
seele.backup = {
  enable = true;
  repositoryFile = "/var/lib/seele-backup/credentials/repository";
  passwordFile = "/var/lib/seele-backup/credentials/password";
  # Add real stable files from the declared path list, not generated canaries.
  restoreSamples = [ "/etc/machine-id" "/home/silash/Documents/a-real-file.md" ];
};
```

Those paths illustrate setup; no destination or key has been created. Every
sample must be a regular file in the backup paths, outside exclusions, with no
glob/control characters. Each sample is bounded to 16 MiB, at most sixteen files.
The feature is NixOS-only because this batch targets `nerv`; no daemon is added to
`asuka` without a separate destination and scheduling design.

Once enabled, `restic-backups-seele` runs daily around 02:30 with a persistent
timer and up to thirty minutes of jitter. It tags snapshots `seele`, preserves
every snapshot and never runs forget/prune. A success marker updates only after
the backup command succeeds. A failure sends a static root-to-shell notification
through systembus-notify and remains visible in existing System Health. A missing
or older-than-36-hour success marker produces the existing backup-overdue finding
and alert when the desktop maintenance service runs, including after reboot.

`seele-backup-restore` runs monthly with a persistent timer. Its native verifier
pins one full snapshot ID filtered by host and tag. It dumps each selected real
file into bounded memory, restores it separately with restic's `--verify` into a
fresh mode-0700 runtime tree, refuses symlinks, and compares every byte. Originals
are never restoration targets. A mode-0600 receipt under `/var/lib/seele-backup`
records snapshot, completion time, file names, byte counts and SHA-256 values.
Content and backend errors never reach helper logs. Temporary restores disappear
on success, failure or cancellation. Systemd gives this unit a private temporary
directory, a read-only system view and no home access. Only successful verification
updates `restore-success`; System Health alerts after 35 days without success.
Configured credential files must be readable inside this sandbox; remote backends
must not depend on a hidden root home or interactive authentication.

After provisioning and activation, run the backup and restore units and inspect
the private receipt and health findings. Verify missing/failing destination alerts
and a overdue-marker finding before counting SIL-28 as complete. Preserve a usable
credential/recovery path independent of the backed-up machine: a password stored
only on a failed disk cannot decrypt its backup.

Validation uses the production helper against a disposable encrypted local
repository and synthetic files. The fixture proves exact snapshot bytes after
original edits, original preservation, private receipt, failed/missing samples,
bad credentials and cleanup. Synthetic Nix assertions cover disabled defaults,
runtime references, monthly scheduling, durable markers and health registration.
These checks do not establish remote credentials, live scheduling, real personal
data restores, full host evaluation or a recovery boot. Full host evaluation is
blocked locally by the existing temporary Nix version; no Nix was installed.

Exclusions are absolute literal file or directory paths. Patterns and negation are refused so evaluation can prove that every selected restore sample lies outside excluded trees; an excluded sample or ancestor fails before activation. Choose an unrelated sample or narrow the excluded tree.
