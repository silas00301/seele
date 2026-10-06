# Restore a separate file copy

Once scheduled backups from SIL-28 are configured, the optional backup browser
inherits their repository/password/backend-file references. It stays disabled
when backups are not configured. `seele-restore-file` opens the native workflow;
Yazi's manager layer offers `<A-r>` for its hovered file. An explicit original
absolute path can also find a deleted file. This interface does not use Vicinae.

Choose a backed-up regular-file version, then **Preview**, **Compare with
current**, or **Restore a copy**. Quick Look handles supported images, text,
media and PDFs using a private runtime file. Close its layer before returning to
the backup dialog. Comparison shows SHA-256 and sizes; UTF-8 files up to 1 MiB
also get a bounded unified diff. Missing current files do not prevent restore.

Restored copies are mode 0600 and published only to a new destination. Choosing
the original or an existing destination never overwrites it. Temporary previews
and comparison files are removed when the workflow exits. No backup bytes,
file-version history or credentials are added to the vault or persistent cache.

The unprivileged UI invokes one fixed root helper through run0, which may ask
for normal polkit authentication after an explicit action. The helper supports
only exact file-version search and file-byte extraction. It is limited to the
configured user's home, snapshots tagged `seele` on the configured host, regular
files at most 16 MiB, and at most 256 matching versions. Snapshot IDs are full
immutable IDs and are checked against that exact path again before extraction.
No shell evaluates the path. Filenames containing wildcard characters remain
literal. The root helper does not write a restore destination or change originals.

Credential references remain outside the Nix store. Files must be private,
owned by the executing account (root when packaged), single-link regular files
under trusted directories. A fresh restic process clears inherited environment,
uses no persistent cache, and has a bounded lifetime. Optional backend files
accept only documented supported keys as strict, unquoted `KEY=value` lines;
unsupported keys or shell/systemd quoting fail closed. Local, S3, B2, Azure,
Google Cloud, REST and configured SFTP backends are supported by the wrapper;
rclone and additional provider-specific options need further integration.

To configure separately before SIL-28 is merged, explicitly set
`seele.backup.browser.enable`, `repositoryFile` and `passwordFile`. After merging
SIL-28, its configuration becomes the default. This independent PR does not
invent or initialize a destination, read existing credentials during development,
or activate a host.

An encrypted disposable-repository fixture verifies old bytes, exact paths,
filtering and original preservation. Fake UI fixtures verify preview retention,
comparison, exclusive copies and cleanup. These do not establish real-account
restore readiness: authenticate on nerv and restore one real personal sample
before using this as evidence for SIL-29. Full package/host builds, native dialog
and Quick Look focus, backend credentials, and root helper authentication remain
live acceptance checks.
