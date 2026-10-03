"""Small, asserted bridge additions against the pinned official Desktop source."""
import pathlib
import sys
import re
import json
root = pathlib.Path(sys.argv[1])
assets = pathlib.Path(sys.argv[2])
# Project numeric design tokens from the installed shared Theme, never keep a
# second set of sizes or opacities in the Electron renderer.
theme = pathlib.Path(sys.argv[3]).read_text()
tokens = {}
for key in ["textBody", "radius"]:
    tokens[key] = float(re.search(r"readonly property int " + key + r": (\d+)", theme)[1])
for key in ["hoverColor", "pressColor", "selectedColor", "cardColor", "separatorColor"]:
    tokens[key] = float(re.search(r"readonly property color " + key + r": alpha\([^,]+, ([\d.]+)\)", theme)[1])
(root / "apps/desktop/src/store/seele-tokens.ts").write_text("export default " + json.dumps(tokens) + " as const\n")
def insert(name, needle, replacement):
    path = root / name
    text = path.read_text()
    if text.count(needle) != 1:
        raise RuntimeError(f"Upstream seam changed: {name}: {needle!r}")
    path.write_text(text.replace(needle, replacement))
for source, target in [("desktop-theme.ts", "apps/desktop/electron/seele-theme.ts"), ("renderer-theme.ts", "apps/desktop/src/store/seele-theme.ts"), ("desktop-lifecycle.ts", "apps/desktop/electron/seele-lifecycle.ts"), ("renderer-lifecycle.ts", "apps/desktop/src/store/seele-lifecycle.ts")]:
    (root / target).write_text((assets / source).read_text())
insert("apps/desktop/electron/main.ts", "import fs from 'node:fs'", "import { setPrimaryWebContentsId } from './seele-lifecycle'\nimport './seele-theme'\nimport fs from 'node:fs'")
insert("apps/desktop/electron/main.ts", "  const createdMainWindow = mainWindow", "  const createdMainWindow = mainWindow\n  setPrimaryWebContentsId(createdMainWindow.webContents.id)")
insert("apps/desktop/electron/preload.ts", "contextBridge.exposeInMainWorld('hermesDesktop', {", "contextBridge.exposeInMainWorld('hermesDesktop', {\n  seeleTheme: () => ipcRenderer.invoke('seele:hermes-theme'),\n  seeleLifecycle: payload => ipcRenderer.send('seele:hermes-lifecycle', payload),")
insert("apps/desktop/src/global.d.ts", "    hermesDesktop: {", "    hermesDesktop: {\n      seeleTheme?: () => Promise<Record<string, string> | null>\n      seeleLifecycle?: (payload: { state: string; session: string; gateway: string }) => void")
insert("apps/desktop/src/main.tsx", "import './store/active-work'", "import './store/active-work'\nimport './store/seele-lifecycle'\nimport './store/seele-theme'")
# Managed credentials always use Electron's Secret Service backend. Never
# accept basic_text or the upstream per-save plaintext escape hatch.
insert("apps/desktop/electron/main.ts", "  return _secretStoragePolicy\n}", "  return { on: true, migrated: true }\n}")
insert("apps/desktop/electron/main.ts", "function setSecretStoragePolicy(next: SecretStoragePolicy) {", "function setSecretStoragePolicy(next: SecretStoragePolicy) {\n  if (!next.on) throw new Error('Seele requires the system wallet for Hermes credentials.')")
# Reject the toggle before upstream decrypts and rewrites its persisted stores.
# A setter-only guard would run after plaintext had already reached disk.
insert("apps/desktop/electron/main.ts", "function applySecretStorageEncryption(on: boolean) {", "function applySecretStorageEncryption(on: boolean) {\n  if (on !== true) throw new Error('Seele requires the system wallet for Hermes credentials.')")
insert("apps/desktop/electron/hardening.ts", "  const allowPlainText = options?.allowPlainText === true", "  const allowPlainText = false\n  if (safeStorageApi?.getSelectedStorageBackend?.() === 'basic_text') throw new Error('Unlock the system wallet before saving Hermes credentials.')")
# A default, not an env override: changing URL/auth in Desktop Settings wins.
insert("apps/desktop/electron/main.ts", "  let config = { mode: 'local', remote: {}, profiles: {} }", "  let config = { mode: 'remote', remote: {url: process.env.SEELE_HERMES_GATEWAY || 'http://hermes:9119', authMode: 'oauth'}, profiles: {} }")
# Keep errors actionable for the managed wallet policy; upstream fallback
# suggestions would point users at plaintext or credential environment overrides.
insert("apps/desktop/electron/hardening.ts", "        'confirm the plain-text storage option when prompted in Settings → Gateway, ' +\n        'or set HERMES_DESKTOP_REMOTE_URL and HERMES_DESKTOP_REMOTE_TOKEN in your environment.'", "        'Unlock the system wallet and retry in Settings → Gateway.'")
insert("apps/desktop/electron/hardening.ts", "        'Set HERMES_DESKTOP_REMOTE_URL and HERMES_DESKTOP_REMOTE_TOKEN in your environment as a fallback.'", "        'Unlock the system wallet and retry in Settings → Gateway.'")

# Migrate a legacy plaintext gateway token when settings are saved, even if
# the token field was not retyped. Encryption failure aborts the save and
# leaves the existing record intact; memory-only connection tests stay usable.
insert("apps/desktop/electron/hardening.ts", "  if (!incomingToken) {\n    return existingToken\n  }", "  if (!incomingToken) {\n    if (persistToken && existingToken?.encoding === 'plain' && existingToken.value) {\n      return encryptSecret(String(existingToken.value))\n    }\n    return existingToken\n  }")

# A failed automatic cookie refresh must not turn every polling request into
# another visible sign-in window. Keep silent attempts on upstream's bounded
# hidden path, and share one attempt per gateway, session partition and mode.
# Explicit sign-in has its own slot so a hidden retry cannot swallow that action.
insert("apps/desktop/electron/main.ts",
       "    const hiddenRecovery = background || !canShowInteractiveOauthLogin()",
       "    const hiddenRecovery = silent || background || !canShowInteractiveOauthLogin()")
insert("apps/desktop/electron/main.ts", "function openOauthLoginWindow(", """const seeleOauthLoginFlights = new Map<string, Promise<unknown>>()
function openOauthLoginWindow(baseUrl, options: Parameters<typeof runOauthLoginWindow>[1] = {}) {
  const hidden = options.silent || options.background || !canShowInteractiveOauthLogin()
  const key = JSON.stringify([
    resolveOauthPartitionForUrl(baseUrl, options),
    normalizeRemoteBaseUrl(baseUrl),
    Boolean(hidden)
  ])
  const existing = seeleOauthLoginFlights.get(key)
  if (existing) return existing
  const pending = runOauthLoginWindow(baseUrl, options)
  seeleOauthLoginFlights.set(key, pending)
  const release = () => { seeleOauthLoginFlights.delete(key) }
  pending.then(release, release)
  return pending
}
function runOauthLoginWindow(""")
