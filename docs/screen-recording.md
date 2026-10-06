# Short recordings

On nerv, `Super + Ctrl + Alt + S` opens the native recording workflow. Choose
Silent, a microphone, or one running application stream; click a suggested
window or drag a region. A visible dialog offers **Stop and review** or
**Discard**. Recordings are limited to two minutes. Timeout discards the capture.

Stopping saves and copies the original under `~/Videos/Recordings`. The next
dialog accepts start and end in seconds for a separate trimmed MP4. Cancel
retains the original. The final dialog offers an explicit public 0x0.st upload,
with a 24-hour secret link; keeping it local is always available. No microphone,
application audio or upload is selected implicitly.

Application audio captures one existing stream and keeps it audible on its
current output. A restarted application or newly created stream needs a new
recording. It is an exclusive alternative to microphone capture.

Native fixtures cover argument and file safety, but actual capture, encoder
compatibility, dialog visibility within a chosen region, clipboard recipients
and PipeWire remapping require live checks on nerv. A chosen region records
whatever appears inside it, including another window moving into the area.
