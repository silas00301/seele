// Metadata only: never copy prompts, transcript, titles, audio or desktop content.
import { createHash } from 'node:crypto'
import { spawn } from 'node:child_process'
import { ipcMain } from 'electron'

let busy = false
let last = 0
ipcMain.on('seele:hermes-lifecycle', (event, value: unknown) => {
  if (busy || Date.now() - last < 500 || !value || typeof value !== 'object') return
  const frame = event.senderFrame
  // Preview guests and arbitrary web pages never acquire the publisher bridge.
  if (!frame || frame !== event.sender.mainFrame || !frame.url.startsWith('file:')) return
  const data = value as Record<string, unknown>
  if (Object.keys(data).some(key => key !== 'state' && key !== 'session')) return
  if (!['disconnected', 'idle', 'listening', 'thinking', 'speaking'].includes(String(data.state))) return
  if (typeof data.session !== 'string' || data.session.length > 1024) return
  const report = { state: data.state, session: data.session ? createHash('sha256').update(data.session).digest('hex') : '' }
  last = Date.now()
  busy = true
  const child = spawn('@hermesPublisher@', ['publish'], { stdio: ['pipe', 'ignore', 'ignore'], timeout: 2000 })
  child.on('error', () => { busy = false })
  child.on('close', () => { busy = false })
  child.stdin.on('error', () => {})
  child.stdin.end(JSON.stringify(report) + '\n')
})
