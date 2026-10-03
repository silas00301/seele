// Metadata only: never copy prompts, transcript, titles, audio or desktop content.
import { createHash } from 'node:crypto'
import { spawn } from 'node:child_process'
import { ipcMain } from 'electron'

type Report = { state: string; session: string; gateway: string }
// The primary Desktop owns this readout. Secondary chats and browser popouts
// have independent renderer stores and must not overwrite its active state.
let primaryWebContentsId: number | null = null
export function setPrimaryWebContentsId(id: number) {
  primaryWebContentsId = id
}
let busy = false
let last = 0
let pending: Report | null = null
let timer: ReturnType<typeof setTimeout> | null = null
function flush() {
  if (busy || !pending || timer) return
  const delay = Math.max(0, 500 - (Date.now() - last))
  if (delay) { timer = setTimeout(() => { timer = null; flush() }, delay); return }
  const report = pending
  pending = null
  last = Date.now()
  busy = true
  const child = spawn('@hermesPublisher@', ['publish'], { stdio: ['pipe', 'ignore', 'ignore'], timeout: 2000 })
  let finished = false
  const finish = () => { if (finished) return; finished = true; busy = false; flush() }
  child.on('error', finish)
  child.on('close', finish)
  child.stdin.on('error', () => {})
  child.stdin.end(JSON.stringify(report) + '\n')
}
ipcMain.on('seele:hermes-lifecycle', (event, value: unknown) => {
  if (primaryWebContentsId === null || event.sender.id !== primaryWebContentsId) return
  if (!value || typeof value !== 'object') return
  const frame = event.senderFrame
  // Preview guests and arbitrary web pages never acquire the publisher bridge.
  if (!frame || frame !== event.sender.mainFrame || !frame.url.startsWith('file:')) return
  const data = value as Record<string, unknown>
  if (Object.keys(data).some(key => key !== 'state' && key !== 'session' && key !== 'gateway')) return
  if (typeof data.state !== 'string' || !['disconnected', 'idle', 'listening', 'thinking', 'speaking'].includes(data.state)) return
  if (typeof data.session !== 'string' || data.session.length > 1024) return
  let gateway = ''
  if (data.gateway !== undefined && data.gateway !== '') {
    if (typeof data.gateway !== 'string' || data.gateway.length > 2048) return
    try {
      const url = new URL(data.gateway)
      if (!['http:', 'https:'].includes(url.protocol)) return
      url.username = ''
      url.password = ''
      url.search = ''
      url.hash = ''
      gateway = url.href
    } catch { return }
  }
  pending = { gateway, state: data.state, session: data.session ? createHash('sha256').update(data.session).digest('hex') : '' }
  flush()
})
