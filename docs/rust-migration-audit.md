# Rust migration audit

This is the implementation and validation record for the migration from the
fetched `main@origin` revisions below. It accompanies the source changes; it is
not a certification that the system has no remaining vulnerabilities or that
every hardware workload is optimal.

| Repository | Reviewed baseline |
| --- | --- |
| Seele | `a4dfa11b367fec2f979b48d2d9cb8292298b0f3d` |
| Seele Shell | `d16edb8851989948cb8a45b5b6be9934e6732dc1` |

The review covers first-party runtime code, active and dormant configuration,
package and extension boundaries, shared visual components, and their retained
behavioral tests. Upstream package implementations, remote account policy,
firmware and live host state have separate trust boundaries. No Nix distribution
was installed, no host was activated, and no real credentials were read during
this work. Validation uses temporary files, fake executables, private services,
synthetic model requests and public development dependencies.

## Resulting architecture

The shell repository owns one Cargo workspace, lock file, release profile and
native package builder. Independent services remain separate binaries; shared
Rust libraries own their common file, process, framing, cancellation and policy
code. The broker and stateful integrations use private IPC where several clients
need one state owner. In-process display algorithms use native Qt and extension
bindings rather than starting a helper for every render.

See [the native workspace guide](../seele-shell/docs/native-workspace.md) for the
ownership table and contribution rules. Individual protocol and safety contracts
remain beside each component. This avoids reproducing those contracts in several
documents that can drift independently.

| Baseline implementation | Native owner |
| --- | --- |
| Python Codex broker, runner and health helper | `broker` and shared `runtime::codex` |
| Python maintenance state, publishers and server | `maintenance` |
| Python Fish assistance and stderr retention | `shell-ai` |
| Python failure collector and reporter | `failure-analysis` |
| Python resident AI prompt controller | `prompt` |
| Python Home Assistant and transfers workers | `integrations` |
| Python GitHub projection | `runtime::github` |
| Python portable materialization, catalogs, input graph and project text | `config-tools` |
| Shell screenshot, Spotify, Brave preferences and Windows boot-selection policy | `desktop-tools` |
| Shell repository checks, updates and generation operations | `repo-tools` |
| JavaScript editor, calendar, media, notification, health and display policy | `qml-core` |
| C++ Markdown matching and range policy | `markdown-core`; Qt retains document/layout ownership |
| Duplicate agent-hook filesystem writers | `tools::agents` through thin host callbacks |
| Pi terminal footer formatting and revision collection | `qml-core::pi`, an in-process Node-API binding and bounded `repo-tools` endpoint |
| Shell application-launch, configuration and backup wrappers | Native launchers and compiled wrappers |

QML retains its visual tree, layout, materials, font declarations, transparency,
animation declarations and object/signal bindings. Qt remains responsible for
text layout, locale/date conversion, editing, painting and graphics integration.
The shared palette has one fallback and assignment path. Necessary host bindings
must remain small: a JavaScript or TypeScript host API is not a justification
for keeping unrelated policy or subprocess management in the adapter.

Nix expressions and build/activation hooks remain the system's declarative
configuration interface. Development Python/Node/shell fixtures are not running
service implementations. Upstream applications such as Proton VPN, browsers,
Vicinae and editor/agent hosts retain their supported implementations; this
migration does not replace their upstream authentication or plugin protocols.
The [Proton compatibility boundary](../modules/features/programs/_proton-vpn/README.md)
documents why its authentication patch remains within that upstream package.

## Security corrections

The common failure patterns were inconsistent subprocess ownership, partial
resource bounds, filesystem trust assumptions, stale asynchronous work and
policy spread between a service and its clients. Replacing a language alone does
not correct these patterns; the native boundaries and their tests do.

| Boundary | Correction and evidence location |
| --- | --- |
| Inherited Codex instructions | Approved private HOME/CODEX_HOME with only validated existing file-auth delegation; common no-tools flags and actual-wire first/resume/image gates. [`runtime`](../seele-shell/projects/runtime/README.md) |
| Process floods, hangs and orphaned children | Shared combined-output limits, deadlines, cancellation and process-group ownership; explicit successful handoff for clipboard/GUI owners. [`tools`](../seele-shell/projects/tools/README.md) |
| Private files and local IPC | Bounded regular-file reads, ownership/mode/link checks, descriptor-relative atomic publication, no-replace creation and peer-verified bounded sockets. [`workspace guide`](../seele-shell/docs/native-workspace.md) |
| Screenshot publication and upload consent | Exclusive timestamp reservation, private frozen captures, explicit upload consent and descriptor-pinned upload input prevent path replacement from changing the reviewed image. [`desktop tools`](../seele-shell/projects/desktop-tools/README.md) |
| Credential redaction | Escaped and unterminated quoted secrets, fine-grained GitHub tokens and Basic authorization headers are covered by shared regression tests; inference serialization is bounded before cloning. [`runtime`](../seele-shell/projects/runtime/README.md) |
| Stale prompt context or answer insertion | Panel generations, consumed consent, exact reviewed payload snapshots and validated source-process identity. [`prompt tests`](../seele-shell/projects/prompt/tests/controller.rs) |
| Privileged generation switching | Immutable reviewed target and running identities, successful matching diff before confirmation, and revalidation after escalation. [`Vicinae`](../seele-shell/projects/vicinae/README.md) |
| Bluetooth authorization | Pinned BlueZ sender, nonce-bound stdin answers, bounded worker admission and generation cancellation before trust. [`parent audit`](security-configuration-audit.md) |
| Notes publication and stale cache | Vault containment, exclusive creation, bounded recovery/recording, content conflicts and conservative cache invalidation. [`tools`](../seele-shell/projects/tools/README.md) |
| Transfer retry and repeated writes | Exact retry identity, bounded jobs/clients/notifications, exclusive publication and batch seen-state updates. [`transfers`](../seele-shell/projects/transfers/README.md) |
| Untrusted notification and device text | Plain-text labels, controlled markup, canonical local-image policy, advertised action ordering and bounded native notification state. [`native UI policy`](../seele-shell/projects/qml-core/README.md) |
| Qt conversion allocation bypass | Explicit primitive/container type whitelist and traversal budget before JSON conversion; custom metatype conversion is rejected. [`boundary test`](../seele-shell/tests/native-functions-bounds.cpp) |
| Pathological Markdown input | Indexed backtick matching, bounded inline parsing, independent PCRE match contexts and structural-only fallback; guarded Qt document lifetime. [`Markdown core`](../seele-shell/projects/markdown-core/README.md) |
| Portable launch interpretation | Bounded data substitutions and direct exec preserve arguments/PID; templates cannot run shell commands. [`configuration tools`](../seele-shell/projects/config-tools/README.md) |
| Unknown NetworkManager modes in Quickshell | Shared local upstream patch validates wire values before narrowing and supplies a defensive enum fallback. A sanitizer regression extracts the pinned implementation and covers all 256 enum values plus wide wire boundaries. [`shared Quickshell package`](../seele-shell/packages/core/quickshell.nix) |
| Electron sandbox downgrade | Removed both the explicit T3 launcher flag and the AppRun fallback that disabled Chromium isolation; corrected the pinned AppImage wrapper API. [`release fixture and sources`](../modules/packages/_t3code/README.md) |
| Host privilege and memory defaults | Removed unused raw keyboard access, confirmed Bluetooth repair, compositor-aware suspend inhibition and sensitive-service core limits. [`parent audit`](security-configuration-audit.md) |

The user explicitly approved the Codex authentication isolation contract after
review. Metadata validation does not read credential bytes. The pinned Codex
file-auth writer follows the delegated file when refreshing; keyring-only auth
fails closed. A different upstream auth-storage implementation or model requires
rerunning the documented actual-wire gates. An early misconfigured synthetic
fixture reached the default API endpoint and received an authentication failure;
the corrected successful gates restrict their synthetic traffic to loopback and
use dead proxies outside it. No real account was used.

## Performance evidence

Measurements describe their stated workload on the validation machine. They do
not establish a whole-system speedup, frame-time guarantee, energy optimum, or
equivalent results on either production host. Release optimization remains
portable; CPU features are detected at runtime rather than assumed from the
build machine. No security mitigation or thermal limit was weakened for speed.

| Workload | Observed result | Scope |
| --- | --- | --- |
| RGB grayscale conversion | 3.85× at 1920×640; 3.90× at 3840×640; 2.94× at 3840×2160 | Median scalar versus detected SIMD, including allocation, AMD EPYC 9354P; all 16,777,216 RGB values checked for exact output |
| Offline 200-node input report | Python median 65.75 ms; Rust 8.59 ms; median peak RSS 14,464 versus 3,072 KiB | 40 alternating runs, warm filesystem cache, equal JSON output; process startup plus graph projection |
| Unmatched-backtick Markdown block | About 4.9 s reduced to under 1 ms | Approximately 131k characters in the parser benchmark; excludes Qt layout/painting |
| 1,000-entry notification idle tick | 6.39 ms snapshot roundtrip versus 4.2 µs resident state | Rust JSON input/output; excludes Qt conversion/rendering; fixed-size timer input |
| Pi unchanged footer redraw | 288.3 µs previous path versus 4.8 µs cached native path | 10,000 redraws using the actual terminal UI host; mostly completed-line caching, not whole-agent latency |
| Transfer panel unseen updates | One durable batch replaces one full-history write per unseen group | Protocol behavior, not a machine-dependent timing claim |

The grayscale and Markdown benchmarks are checked into the workspace. The input
comparison fixture accepts an original report extracted from the recorded parent
revision. The notification benchmark is documented beside its native state
implementation. Caches and event-driven listeners reduce repeated work; bounded
worker pools prevent nested thread oversubscription and unbounded queues.

## Evidence and remaining validation

Retained behavioral assertions run through native executables or the same native
policy library. New regression tests cover concrete trust, lifetime and resource
boundaries. In addition to component protocol suites, validation has established:

- Exact Qt format-property and block-state equality over 3,017 seeded/fixed
  Markdown documents, plus checked-in baseline golden documents.
- Real Notes typing, undo/redo, caret, task-box and rendering behavior, including
  destroyed-document cleanup: 15 checks on both Qt 6.4.2 and Qt 6.11.2.
- 4,140 date/editor comparisons across UTC, Berlin and Sydney, including DST,
  leap centuries, constructor overflow and UTF-16 boundaries.
- 1,731 media-policy comparisons, including Unicode, selection and type edges.
- All 32 final JavaScript-host fixture suites pass, including the release-linked
  Node binding's 20,000 ownership cycles and four concurrent worker isolates.
- 2,002 exact Pi footer comparisons using the actual host terminal library,
  including ANSI colors, Unicode, width constraints and lifecycle cancellation.
- Of 26 shared QML components, 22 are byte-identical to the baseline. The
  remaining four changes are plain-text label security and centralized palette
  assignment, covered by rendering checks.
- All 91 animation declarations across 15 QML files and all 85 shared theme
  token expressions match the baseline after whitespace normalization. The
  unchanged fixed-seed grain generator produces a byte-identical 35,020-byte PNG
  in debug and pinned-compiler release builds
  (`6221ceb2a5f4785c32761e3da7fdf46186ca1f80f6ecda069c83e4ca4bf09beb`).
- Palette property/pixel comparisons, plain-label rendering, stable-row identity
  and existing animation/hover fixtures. The exact configured Maple Mono NF CN
  font is used for Qt 6.11.2 rendering checks.
- Native Qt return values preserve actual JavaScript arrays and own object keys,
  verified with source and installed SystemState fixtures.
- The pinned-compiler workspace run passes 239 tests, with two benchmark-only
  tests intentionally ignored. Installed Codex and fzf gates are enabled with
  synthetic configuration and loopback-only model traffic. The lockfile audit covers 265
  dependencies against 1,243 RustSec advisories, with zero reported
  vulnerabilities or warnings (database snapshot from 2026-09-09).
- Synthetic real-process gates for Codex, Fish/fzf, BlueZ, PipeWire, screenshot
  consent, OCR/QR/barcodes and daemon handoff, as documented by their owners.

The pinned Rust 1.97.1 compiler passes strict Clippy across all workspace targets
and features. Portable runtime, configuration, repository, desktop and UI-policy
crates also type-check for Apple Silicon, Intel Darwin and ARM Linux. These cross-target
checks do not execute macOS applications or validate its native linker/runtime.

The exact pinned Quickshell source was built against an isolated Qt 6.11.2 SDK.
The complete shell configuration passes its real-runtime compilation fixture on
a private headless Sway compositor. Source and installed shell layouts, Notes,
lock, greeter and polkit configurations load successfully. The focus timer
passes in both layouts. Home Assistant setup, lights, devices and
offline fixture PNGs are byte-for-byte identical to the recorded shell baseline
under the same font, Qt and compositor environment. This is specific visual
comparison evidence; it does not establish equality of every possible desktop
state or production GPU output.

Standalone formatting and syntax checks pass for all 161 Nix files and all
11 changed Bash fixtures. Static package-path checks find no dangling source
references. These checks do not evaluate Nix expressions. The complete optimized
workspace build passes with Rust 1.97.1. All 51 declared executables are native
ELF64 binaries, with no interpreter wrappers; their combined size is
134,234,624 bytes in this validation build. After compiler contention cleared,
the unchanged 15-second shell-load gate passes in 2.886 seconds for source and
2.884 seconds for the refreshed installed layout. Notifications pass using the
optimized controller, and the optimized broker passes its protocol and actual
Codex loopback gates. Earlier shell-load timeouts during concurrent optimized
compilation were diagnosed with a longer temporary fixture; the committed
assertions and timeout were retained.

The migration is reviewed through linked draft pull requests. The parent pins
the shell PR's exact source revision; refresh that pin if the shell PR is rebased
or squash-merged. The PR workflow leaves the main bookmarks unchanged and keeps
existing lock data only after verifying that the child lock is identical and the
parent lock has no pending changes. It performs no Nix evaluation or activation.
See the [repository's submodule workflow](../.agents/skills/seele-shell/SKILL.md).
This record does not claim a rebuild-ready or activated host.

Nix evaluation, native-host closure builds and actual Hyprland/hardware behavior
cannot be inferred from standalone compilation. Required host checks include
sleep/lock completion, PAM/token login, audio/device routing, compositor visual
parity and desktop input insertion. T3 Code's real sandboxed Electron startup
also needs a host check: this validation machine rejects writing the user
namespace UID map, so only the exact launcher and upstream sandbox selection
were verified here. Source changes do not revoke group membership
from an existing session or alter services already running on the host.

Residual boundaries include uncooperative external-editor races during existing
note replacement, private staging files left by SIGKILL/power loss, upstream
authentication and supply-chain trust, remote account ACLs, and the authority of
the same user or root. Parser deadlines are cooperative limits, not hard realtime
guarantees. These are explicit limits on the claims this audit can support.
