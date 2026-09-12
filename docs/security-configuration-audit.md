# Parent configuration security audit

This review compared the active parent configuration with `main@origin` at
`a4dfa11b`, and followed its shell interfaces from the shell baseline `d16edb88`.
It covers repository configuration and its documented upstream semantics. It did
not inspect private credentials, activate a host, enroll hardware, contact a
configured account, or change the running machine. No Nix distribution was
installed. The native worker implementation and fixture evidence live in the
shell component READMEs; this report records the parent configuration boundary.

## Corrected findings

| Boundary | Baseline evidence | Resulting configuration |
| --- | --- | --- |
| Raw keyboard access | Voxtype disabled its evdev hotkey and used Hyprland press/release bindings, while its NixOS module still added the desktop user to `input`. | Removed the unused system feature and host import. Dictation remains a Home Manager feature using the compositor's existing bindings. |
| Bluetooth bond replacement | `JustWorksRepairing = "always"` accepted peer-initiated replacement of an existing bond automatically. | `confirm` routes replacement through agent authorization. Fast connectability and ordinary bonded reconnects remain enabled. A device whose bond changed may require opening the existing pairing window and accepting the dialog. |
| Lock before suspend | `before_sleep_cmd = "loginctl lock-session"` was asynchronous; hypridle's default automatic mode recognizes `hyprlock` by executable name, while this host uses Seele Lock. | Explicit `inhibit_sleep = 3` holds the delay inhibitor until Hyprland reports a locked session. Compositor lock confirmation governs the transition, subject to logind's maximum inhibition delay. |
| Sensitive crash memory | Shell, PolicyKit dialog, Taildrop, dictation, and the PAM wallet bridge lacked a service-specific crash-dump opt-out, despite holding authentication material, clipboard/context data, transferred contents or audio in memory. | Added `LimitCORE = 0` to those service processes. Dictation also uses `UMask = "0077"`. Existing broker, maintenance and failure-report services already had this core limit. |
| Nix distribution ownership on Darwin | The Darwin feature declared `nix.enable = true` and `nix.package = pkgs.nix`, although the shared Determinate module overrides that ownership. | Removed the inert conflicting declarations and unused package argument. The existing system installation remains the sole Nix distribution. |

The keyboard privilege finding is supported by [Voxtype's official security
policy](https://github.com/peteonrails/voxtype/security): compositor bindings with
the internal hotkey disabled need no input group; raw event access permits
system-wide key capture. OpenLogi's distinct `uinput` group remains because its
configured device-remapping feature needs input injection.

The Bluetooth policy was checked against [BlueZ's implementation of
`device_confirm_passkey`](https://github.com/bluez/bluez/blob/master/src/device.c).
Its `always` branch immediately accepts an existing paired device's Just Works
request; `confirm` proceeds to the registered agent's authorization callback for
a peer-initiated request. The existing native pairing agent handles that callback
and presents the existing shell dialog. No Bluetooth devices were paired or
reconfigured during validation.

The suspend behavior was checked against [hypridle's implementation](https://github.com/hyprwm/hypridle/blob/main/src/core/Hypridle.cpp)
and [its configuration reference](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/).
Automatic mode searches the configured commands for `hyprlock`; explicit mode 3
uses the compositor's lock notification. This is a delay inhibitor, not a promise
that a broken lock client can prevent suspend indefinitely. Missing or late lock
confirmation must still be exercised on the actual host.

[systemd's coredump documentation](https://systemd.io/COREDUMP/) confirms that its
handler respects the process core resource limit. This opt-out prevents ordinary
service crashes from persisting their memory images. It does not make their
memory inaccessible to the same user or root, erase existing dumps, or override
a separately configured handler that ignores the limit. The limit is inherited
by children; debugging a child launched from a protected service may require an
explicit separate development launch.

## Reviewed trust boundaries

| Area | Evidence and retained boundary |
| --- | --- |
| SSH | The host's OpenSSH configuration permits only the declared user, requires public keys, disables password and interactive authentication, and denies root login. Its service does not start automatically. The explicit shell selector owns the mutually exclusive OpenSSH/Tailscale SSH state. The ordinary port-22 firewall opening remains configured for the selected OpenSSH path. |
| Tailscale | The service is explicitly enabled, assigns its operator to the desktop user, disables upstream logging, and enables client routing features. Tailnet identity and ACL policy remain external account state; the repository cannot prove their correctness. The configured Tailscale transport firewall opening remains necessary for the existing feature. |
| Other network features | KDE Connect remains an intentionally enabled discovery/transfer service. Printing is disabled. No repository rule disabling the firewall or broadly trusting an interface was found. This static review does not enumerate upstream default listeners or prove the runtime firewall state. |
| PAM and privileged approval | Login and Seele Lock retain password-first hardware-token second-factor ordering. Sudo and PolicyKit retain the intentional token-or-password approval policy. The relying-party identifier is enrolled credential state and was preserved. The narrowly relaxed PolicyKit helper device/home access remains necessary for the token and its user-owned enrollment file. |
| Windows reboot | The PolicyKit exception allows only the declared user to start the single `reboot-windows.service`; it does not authorize arbitrary systemd units or verbs. The root helper selects the existing EFI entry by its declared label and uses packaged commands. Its intended reboot authority remains available. |
| Root failure reporter | The collector stays a root oneshot with private temporary storage, restrictive umask, no new privileges, a timeout and no core dumps. Its runtime implementation handles the root-to-user report handoff; the service cannot be made an unprivileged user service while retaining failed system invocation access. |
| Private inference and maintenance | Socket-activated user services retain mode-0600 sockets, restrictive umask and no-new-privileges settings. Their native protocols add peer and bounded-request checks. Outgoing inference and authenticated diagnostic sources require network access; private source data and repair authorization belong to the services' own contracts. |
| Desktop services | Shell and authentication helpers run in the intended user/greeter contexts. A blanket `NoNewPrivileges`, inaccessible home, or denied D-Bus policy would break explicitly supported application launch, authentication, vault and desktop-control behavior; restrictions were applied at the actual private-file/process/socket boundaries instead. |
| Secret stores and hooks | Home Assistant delegates token storage to Secret Service. Password-manager and PAM wallet integrations retain their native stores. Lifecycle hooks invoke packaged native helpers with constant agent/status arguments; prompt/context data flows through their bounded stdin contracts. No secret-bearing Nix-store configuration was introduced. |
| Browser and package trust | Browser tracking protection and managed update policy remain intact; disabling application self-update is deliberate for a declarative package. The explicitly trusted Vicinae binary cache and managed browser-extension publishers remain supply-chain trust decisions. A source audit cannot verify future upstream releases or remotely served extensions. |
| Darwin | Determinate ownership, Touch ID approval and configured desktop tools were reviewed statically. Linux checks cannot establish Darwin service, Keychain, application firewall, signing, or GUI behavior. The report makes no claim about unconfigured local macOS settings. |
| Hardware and performance | Existing CPU governor, bounded build parallelism and compressed swap settings remain unchanged. No speculative-execution mitigation, thermal limit, firmware setting, secure-boot enrollment, hardware identifier or signing value was weakened for speed. |

## Bluetooth transport follow-through

Tracing the configuration confirmation path also found private pairing data in
process arguments and missing bounds in the native agent. The shell now receives
only a request nonce through its existing IPC notification, then obtains the
matching mode-0600 request through a bounded native reader. Answers travel as
bounded stdin JSON and are checked against the current nonce and request kind
before the private answer is published. Stale or dismissed completions cannot
reopen the dialog. Passkeys, PINs and request data are absent from the UI's
subprocess arguments. The old answer-in-arguments interface was removed after
migrating every repository caller and fixture to stdin.

The agent pins the current BlueZ bus owner and rejects callbacks from any other
sender, uses random request nonces, rejects oversized/linked/public/non-regular
answer files, validates codes without truncating characters, and observes process
shutdown and the pairing-window deadline while awaiting an answer. Untrusted
service authorization is confirmed through the same dialog. One bounded worker
awaits an answer while the D-Bus loop remains available. Queued cancellation and
owner changes are handled before successful results can grant trust; generations
and exact nonces prevent stale completion. Cancel and Release stop pending work,
and losing the pinned BlueZ owner closes the agent. Real-device roaming and trust
behavior still require a live Bluetooth validation pass.

## Validation and remaining host checks

Scoped files were formatted with the official standalone nixfmt 1.5.0 binary.
Baseline declarations were read through Jujutsu, and a repository reference scan
confirmed removal of the unused Voxtype system-module names and input-group
assignment. Existing screenshot wrapper changes in `hypr.nix` belong to the
parallel runtime migration and were preserved.

Native tests cover pairing-code validation and random nonce generation. The
private local fixture `seele-shell/tests/bluetooth-pairing.py` covers current and
stale requests, strict answer values, private permissions, symlinks, hardlinks,
FIFOs, oversized files/input, partial-stdin timeouts and credential-free argv.
`seele-shell/tests/bluetooth-pairing.js` executes the production QML handlers to
check supersession, dismissal and stdin transport. The Rust integration test
`cargo test -p seele-tools --test bluetooth` starts a private fake BlueZ bus and
runs the actual agent, checking unauthorized senders, concurrent-request refusal,
Cancel before accepted-answer completion, successful passkey authorization,
Release and owner loss. These fixtures do not access a Bluetooth adapter, the
host system bus or an active desktop session.

Nix evaluation, flake checks, native host builds and activation were not performed
in this audit environment because Nix is unavailable and installation was
forbidden. Formatting establishes parseability, not correct module evaluation.
On the actual hosts, validate the generated units and PAM configuration, test
sleep/lock completion and resume, test Bluetooth bond replacement and receiver
pairing, inspect the effective firewall/listeners, and verify dictation after
logging into a session without the removed group membership. Existing processes
retain supplementary groups until their session is replaced; repository edits
alone do not revoke their current kernel credentials.
