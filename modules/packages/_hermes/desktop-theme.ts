// The desktop framework adapter reads only Seele's published palette. No user
// settings, credentials or desktop content cross this IPC boundary.
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import { ipcMain } from 'electron'
const file = path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'), 'seele-shell/theme.json')
ipcMain.handle('seele:hermes-theme', event => {
  const frame = event.senderFrame
  if (!frame || frame !== event.sender.mainFrame || !frame.url.startsWith('file:')) return null
  try {
    const stat = fs.statSync(file)
    if (!stat.isFile() || stat.size > 65536) return null
    const data = JSON.parse(fs.readFileSync(file, 'utf8'))
    const result: Record<string, string> = {}
    for (const key of ['base', 'mantle', 'crust', 'surface', 'overlay', 'text', 'subtext', 'accent', 'red', 'green', 'yellow']) {
      if (typeof data[key] !== 'string' || !/^#[0-9a-f]{6}$/i.test(data[key])) return null
      result[key] = data[key]
    }
    if (typeof data.fontFamily === 'string' && /^[\w ,.-]{1,128}$/.test(data.fontFamily)) result.fontFamily = data.fontFamily
    return result
  } catch { return null }
})
