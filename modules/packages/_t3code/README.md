# T3 Code AppImage boundary

`../t3code.nix` wraps the checksum-pinned upstream AppImage through the pinned
nixpkgs `appimageTools.wrapAppImage { src = contents; }` API. The extracted tree
removes the old bundled libnotify and applies `appimage-sandbox.patch` before it
enters the FHS compatibility wrapper. The Electron application itself remains an
upstream runtime dependency.

The upstream desktop entry explicitly passed `--no-sandbox`; its AppRun also
silently added that flag when `unshare -Ur true` failed or was missing. The
package removes both automatic paths. AppRun supplies only
`--disable-setuid-sandbox`, because Nix store files cannot serve as a privileged
setuid helper. Chromium's user-namespace and seccomp sandboxes remain enabled;
startup fails when the namespace sandbox cannot be established. No setuid
helper, permissive sysctl, or automatic unsandboxed fallback is installed.

The original AppRun's environment setup, argument forwarding and exit behavior
are preserved. Its Bash entrypoint belongs to upstream AppImage integration;
this patch introduces no new first-party runtime interpreter. The pinned T3
renderer already requests `sandbox: true`, `contextIsolation: true` and
`nodeIntegration: false`.

The focused `passthru.tests.sandbox-launcher` runs the actual patched AppRun
with a synthetic Electron executable and an empty private home. It verifies
empty and URI argument lists, literal spaces and dollar signs, required
library/theme environment forwarding, and absence of the failed-namespace
probe/fallback. No actual Electron window, account, browser profile, firmware,
or system setting is touched. To run the same fixture outside Nix:

```sh
python3 test_sandbox.py /path/to/patched/AppRun /path/to/bash
```

Static verification used the pinned release
`v0.0.41-nightly.20260912.1599`, whose downloaded AppImage SHA-256 matched the
package, and its exact source commit
[`b1e223e2b0d87124883b1410ab52dd6a1338e40d`](https://github.com/pingdotgg/t3code/blob/b1e223e2b0d87124883b1410ab52dd6a1338e40d/apps/desktop/src/window/DesktopWindow.ts).
Electron's [sandbox documentation](https://www.electronjs.org/docs/latest/tutorial/sandbox)
explains why `--no-sandbox` must not be a production default. The pinned
[Electron 44.1.0 dependency list](https://github.com/electron/electron/blob/v44.1.0/DEPS)
names Chromium 152.0.7977.65; its
[zygote initialization](https://github.com/chromium/chromium/blob/152.0.7977.65/content/browser/zygote_host/zygote_host_impl_linux.cc)
selects the namespace sandbox and fails closed when no permitted sandbox exists.

Pinned nixpkgs
[`c5c4a43b0e8056328ec4529f735cabdb8f1942bb`](https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/build-support/appimage/default.nix)
requires `src` for `wrapAppImage`. Its
[Bubblewrap FHS builder](https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/build-support/build-fhsenv-bubblewrap/default.nix)
does not disable nested user namespaces. Its standard kernel enables
`CONFIG_USER_NS`; `security.allowUserNamespaces` defaults to true, and this
repository does not override those defaults or enable the hardened kernel
profile. This is source evidence, not an evaluated or activated host result.

The available validation machine rejects writing `/proc/self/uid_map`, so a
real sandboxed Electron launch cannot be established there. Nix evaluation,
the full package build, and an empty-profile launch on `nerv` remain required
host validation. Do not restore `--no-sandbox` to hide a startup failure.
