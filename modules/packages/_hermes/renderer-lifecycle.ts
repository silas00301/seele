// Read the upstream's actual transport, session and voice stores. No second
// connection or agent is started, and no content crosses the lifecycle bridge.
import { $activeSessionId, $connection, $gatewayState } from '@/store/session'
import { $workingSessionIds } from '@/store/session-states'
import { $voicePlayback } from '@/store/voice-playback'
import { $wakeWord } from '@/store/wake-word'

function publish() {
  const remote = $connection.get()?.mode === 'remote'
  const state = !remote || $gatewayState.get() !== 'open' ? 'disconnected'
    : $voicePlayback.get().status === 'speaking' ? 'speaking'
    : $workingSessionIds.get().length > 0 ? 'thinking'
    : $wakeWord.get().listening ? 'listening' : 'idle'
  window.hermesDesktop?.seeleLifecycle?.({ state, session: remote ? ($activeSessionId.get() || '') : '' })
}
// A heartbeat also retires a killed client honestly in the resident service.
setInterval(publish, 3000)
publish()
