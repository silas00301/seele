# Shell workbenches

These tools share Seele Shell's design tokens and direct Vicinae commands.
The parent change adds their layer namespaces to Hyprland's existing blur rule
and pins their combined, published shell revision. No new daemon, host binding,
flake input or system privilege is required.

| Tool | Open from the shell | Native behavior |
| --- | --- | --- |
| Calculator | Control Center or `seele-shellctl calculator` | Bounded arithmetic parser, six conversion categories and a 32-entry session tape |
| Meeting planner | World Clock → Plan meeting or `seele-shellctl control meeting` | Local-day hour ribbons per IANA zone, DST-aware day moves, working-hour fit, ranked suggestions and Next fit around calendar busy time |
| Colour Lab | Control Center or `seele-shellctl color-lab` | Opaque sRGB parsing, unrounded WCAG thresholds, typography preview and tonal palettes |
| Text workbench | Control Center or `seele-shellctl control text-workbench` | JSON formatting, URL and Base64 transforms, line cleanup and stable deduplication |
| Resources | Control Center or `seele-shellctl control resources` | Live CPU, memory, per-device storage and searchable processes with bounded histories |
| Network activity | Control Center, Network panel or `seele-shellctl control network-activity` | Per-interface receive/send rates and session totals |
| Sensors | Resources header or `seele-shellctl sensors` | hwmon temperatures and fan speeds with driver-stated limits, alarm states and session peaks |

Calculator and text-workbench documents are destroyed on close. Paste and Copy
are explicit. Text transforms reject malformed or oversized data without partial
output; JSON formatting preserves original numeric precision and duplicate keys.
Colour Lab's AA/AAA verdict uses the unrounded ratio, even when its displayed
ratio rounds up to a threshold. Its sampled-colour action is deliberate.

The meeting planner's weekday 09:00–17:00 shading is a guide, not another
person's calendar. Its axis is this computer's local day, 23 or 25 hours long
across a transition, and every selection is one absolute instant, so a repeated
or skipped local hour is never guessed and each participant keeps its actual
local date and offset. With Google Calendar configured it steers around your own
busy time, which it reads and never writes.

Resources, Network activity and Sensors are read-only, local observers. Closing
their panels stops sampling and releases the in-memory session. No process
arguments, packet contents, network probes or historical files are collected,
and Sensors never reads a `drivetemp` disk.

## Validation boundary

Native Rust tests and strict Clippy use the pinned Rust 1.98.1 compiler. Focused
production protocol fixtures, real
Qt interaction tests, QML lint and inspected renders cover the new behavior.
The combined Control Center is tested at desktop, short and compact output sizes,
including non-overlapping tiles, scroll reachability, arrow-key and Tab
navigation, Escape and drag-safe input (`tests/control-center-layout.js`).
The shell package includes these focused checks for the packaged environment.

Local Qt tests for native QML policy use a test QObject bridge to the compiled
Rust CLI; packaged tests use the actual Seele.Core plugin. The published child
revision also passes the parent-exported Seele Shell package build. A live
Hyprland/compositor session remains a separate machine-level check.

The parent pointer is updated with the native `update-submodule --pr --keep-lock`
helper after publication. It checks that old/new child lockfiles are byte-identical
and the tracked parent lock is unchanged. Source-only changes need no new lock,
so the package build remains the independent validation of the resulting pin.
