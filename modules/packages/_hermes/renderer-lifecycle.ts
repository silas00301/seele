// Read the upstream's actual transport, session and voice stores. No second
// connection or agent is started, and no content crosses the lifecycle bridge.
import { $activeSessionId, $connection, $gatewayState } from '@/store/session'
import { $workingSessionIds } from '@/store/session-states'
import { $voicePlayback } from '@/store/voice-playback'
import { $wakeWord } from '@/store/wake-word'

function publish() {
  const connection = $connection.get()
  const remote = connection?.mode === 'remote'
  const state = !remote || $gatewayState.get() !== 'open' ? 'disconnected'
    : $voicePlayback.get().status === 'speaking' ? 'speaking'
    : $workingSessionIds.get().length > 0 ? 'thinking'
    : $wakeWord.get().listening ? 'listening' : 'idle'
  window.hermesDesktop?.seeleLifecycle?.({ state, session: remote ? ($activeSessionId.get() || '') : '', gateway: remote ? connection.baseUrl : '' })
}
// A heartbeat also retires a killed client honestly in the resident service.
setInterval(publish, 3000)
// Store listeners report real state transitions between heartbeats. The main
// process coalesces bursts to one newest metadata record while a child runs.
$activeSessionId.listen(publish)
$connection.listen(publish)
$gatewayState.listen(publish)
$workingSessionIds.listen(publish)
$voicePlayback.listen(publish)
$wakeWord.listen(publish)
publish()
