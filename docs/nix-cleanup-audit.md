# Nix cleanup and secret reference audit

Home Manager's `programs.nh.clean` is the cleanup owner on both hosts. The common
profile imports its named feature. Its one weekly persistent user timer on Linux
and one weekly launchd agent on macOS run `nh clean user`, retaining three user
profile generations and those from the previous three days. This is user-profile
retention; it does not assert that system generations have been pruned.

Arguments are a list: the pinned Home Manager treats a string as one argument on
Darwin, so the previous combined string could not reliably reach nh's flags there.
The timer, retention and command are otherwise unchanged. There is no second Nix
garbage-collection or store-optimisation timer in this repository. Determinate
owns Nix; no additional optimiser is introduced without measured evidence.

Linux preserves nh's stdout/stderr, including its cleanup summary, in
`journalctl --user -u nh-clean.service`. A failed run starts one critical desktop
notification through Seele Shell's existing notification server. This is explicit
because the system failure-analysis generator does not cover user services.
`systemctl --user start seele-nh-clean-failed.service` tests the notification
without running cleanup. The last result is also available through
`systemctl --user show nh-clean.service -p Result -p ExecMainStatus`.

On macOS, the existing launchd agent records stdout/stderr in
`~/Library/Logs/nh-clean.log`, with a private creation umask. This makes failures
and cleanup summaries inspectable without creating a second scheduled job.
Native Darwin evaluation and launchd execution must be checked on asuka.

The repository currently declares neither sops-nix secrets nor agenix secrets,
and no restic password/repository files. Desktop integration credentials belong
to Secret Service through the existing native provider setup flows, while CLI
logins remain in their tools' private mutable state. A secret-name inventory in
Nix would invent an authority these services do not use. No secret contents were
read for this audit. Do not turn wallet contents or token files into CI inputs.

If declarative secret provisioning is introduced, its own module must expose
names/references for missing and unused-name checks. Evaluate those references
without opening their files or printing values; keep paths to decrypted material
outside the store. This audit does not certify runtime credentials, external
backups, or the contents of an already realised Nix store.
