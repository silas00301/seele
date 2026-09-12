# Shared Codex inference

`seele-codex` uses the mode-0600 `%t/seele-codex.sock` user socket. Systemd owns
that socket across broker restarts. `serve` accepts only that inherited socket
and verifies each client's uid. It exits after five idle minutes, and systemd
restarts failures. Any same-user integration may submit; no registration or
consumer credentials are needed. The `nerv` profile installs it.

The CLI reads one JSON value on stdin and writes one JSON value on stdout:

- `seele-codex request`: low-level asynchronous protocol.
- `seele-codex call`: submit, wait for the same job lifecycle, then release nonfailed work.

A request example:

```json
{"op":"submit","request":{"consumer":"github","label":"Notification triage","prompt":"Classify the supplied notification.","context":{"title":"Example"},"input":{"version":"1","schema":{"type":"object","required":["title"]}},"output":{"version":"1","schema":{"type":"object","properties":{"priority":{"type":"string"}},"required":["priority"],"additionalProperties":false}},"class":"background","item":"notification-1","revision":1}}
```

`call` takes the inner `request` object. The only scheduling classes are
`interactive` and `background`. Input/output schemas use JSON Schema 2020-12;
inline schemas only (references are rejected so validation cannot fetch files
or URLs). Each schema has a consumer-owned version. Message size is 256 KiB,
queue capacity is 128 retained jobs, and concurrency defaults to two (1–8).
Consumers provide a deliberately safe label, never a label derived from private
content. Model selection belongs exclusively to `seele.codexBroker.model`.

Every reply carries `ok` and an `epoch`. Submit returns `job.id`. All subsequent
job operations must include that id and epoch. `broker_restarted` means the
consumer must resubmit from its own durable source; broker jobs are memory-only.

Operations are `list`, `status`, `wait`, `cancel`, `retry`, `next`, and `release`.
`list` needs no epoch and returns metadata only, in running/retrying, actual
queue, then terminal order. `status` and `wait` expose a result only after output
validation succeeds. The states are queued, running, retrying, succeeded, failed,
cancelled, and superseded. Typed failures include invalid_input, capacity,
superseded, invalid_state, unknown_job, broker_restarted, broker_unavailable,
model_failure, runtime_failure, and isolation_failure.

Same-consumer item revisions are monotonic integers. New revisions supersede
queued and active older jobs; obsolete results are never delivered. Disconnecting
a submitter does not cancel work. Cancel also stops schema retries. Transient
failures retry twice with bounded backoff; invalid output regenerates until valid,
cancelled, or superseded. Retry reuses a failed request unchanged. Next promotes
one queued job without interrupting active work or changing its scheduling class.
Release discards a terminal request and result. A bounded metadata-only tail
keeps successful, cancelled, and superseded confirmations visible for five seconds;
dismissing a failure removes it immediately. Consumers must release completed
jobs to recover capacity; failures remain available for an explicit retry.

Codex owns authentication. Each attempt runs `codex exec --ignore-user-config
--ignore-rules --ephemeral --sandbox read-only` from an empty private runtime
workspace. The complete installed feature set is disabled, except the flag that
skips host skill discovery; image tools, web search, and project instructions
are also disabled. The output schema lives in an anonymous memfd, prompts travel
on stdin, and JSON events/results remain in memory. Logs are disabled and the
private runtime tree is removed after every attempt, including cancellation.
No integration environment variables are inherited. The broker never logs
exception text or payloads. Operational timing, model, attempts, outcome and
usage are available through metadata.

Validation:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 modules/packages/_codex-broker/test_broker.py
PYTHONDONTWRITEBYTECODE=1 python3 modules/packages/_codex-broker/test_codex.py
```

The second check uses the real Codex executable with a local fake model endpoint.
It verifies that no tools are exposed, structured results and usage are returned,
and runtime files are cleaned. It performs no remote inference. Run it when
updating the packaged Codex version. The lifecycle suite drives two real socket
clients and covers ordering, supersession, failures, retry and release.
