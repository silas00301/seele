#!/usr/bin/env python3
"""Collect and privately present one failed system operation."""

from __future__ import annotations

import argparse
from collections import deque
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import pwd
import re
import secrets
import socket
import stat
import subprocess
import sys
from typing import Iterable, Sequence


MAX_COMMAND_OUTPUT = 64 * 1024
MAX_REPORT = 256 * 1024
MAX_AI_OUTPUT = 24 * 1024
REPORT_LIFETIME_SECONDS = 24 * 60 * 60
UNIT_PROPERTIES = (
    "Id",
    "Description",
    "LoadState",
    "ActiveState",
    "SubState",
    "Result",
    "ExecMainCode",
    "ExecMainStatus",
    "ExecStart",
    "InvocationID",
    "FragmentPath",
    "SourcePath",
    "StateChangeTimestamp",
)
UNIT_RE = re.compile(r"^[A-Za-z0-9_.:@\\-]{1,256}\.service$")
REPORT_ID_RE = re.compile(r"^[0-9a-f]{16}$")
INVOCATION_RE = re.compile(r"^[0-9a-fA-F]{32}$")
DRV_RE = re.compile(r"/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+\.drv")
ANSI_RE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
KERNEL_HINT_RE = re.compile(
    r"\b(?:kernel|oom(?:-kill(?:er)?)?|out of memory|segfault|general protection|"
    r"i/o error|nvme|nvidia|amdgpu|drm|firmware|device reset)\b",
    re.IGNORECASE,
)
SECRET_NAME_RE = re.compile(
    r"(?:pass(?:word)?|token|secret|api[_-]?key|auth(?:orization)?|cookie|credential|private[_-]?key)",
    re.IGNORECASE,
)


def executable(name: str, fallback: str) -> str:
    return os.environ.get(name, fallback)


def bounded(text: str, limit: int, *, tail: bool = False) -> str:
    encoded = text.encode("utf-8", "replace")
    if len(encoded) <= limit:
        return text
    marker = "\n… output truncated …\n"
    payload = encoded[-limit:] if tail else encoded[:limit]
    decoded = payload.decode("utf-8", "replace")
    return marker + decoded if tail else decoded + marker


def clean_text(value: object, limit: int = 2000) -> str:
    if isinstance(value, list):
        try:
            value = bytes(value).decode("utf-8", "replace")
        except (TypeError, ValueError):
            value = repr(value)
    text = ANSI_RE.sub("", str(value))
    text = "".join(character if character in "\t\n" or ord(character) >= 32 else " " for character in text)
    return bounded(text.strip(), limit)


def run_capture(
    arguments: Sequence[str],
    *,
    input_text: str | None = None,
    timeout: int = 15,
    environment: dict[str, str] | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            list(arguments),
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            env=environment,
            cwd=cwd,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return subprocess.CompletedProcess(list(arguments), 124, "", str(error))


def parse_properties(text: str) -> dict[str, str]:
    properties: dict[str, str] = {}
    for line in text.splitlines():
        name, separator, value = line.partition("=")
        if separator and name in UNIT_PROPERTIES:
            properties[name] = clean_text(value, 8000)
    return properties


def parse_journal(text: str) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for line in text.splitlines():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(entry, dict) or "MESSAGE" not in entry:
            continue
        entries.append(entry)
    return entries


def journal_timestamp(entry: dict[str, object]) -> int | None:
    value = entry.get("__REALTIME_TIMESTAMP")
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return None


def format_timestamp(microseconds: int | None) -> str:
    if microseconds is None:
        return "unknown-time"
    try:
        return datetime.fromtimestamp(microseconds / 1_000_000, timezone.utc).isoformat(timespec="milliseconds")
    except (OverflowError, OSError, ValueError):
        return str(microseconds)


def format_journal(entries: Iterable[dict[str, object]], limit: int = 48 * 1024) -> str:
    lines: list[str] = []
    for entry in entries:
        identifier = clean_text(entry.get("SYSLOG_IDENTIFIER") or entry.get("_COMM") or "unit", 80)
        pid = clean_text(entry.get("_PID") or "", 24)
        origin = f"{identifier}[{pid}]" if pid else identifier
        message = clean_text(entry.get("MESSAGE", ""), 2000).replace("\n", " ⏎ ")
        lines.append(f"{format_timestamp(journal_timestamp(entry))} {origin}: {message}")
    return bounded("\n".join(lines), limit, tail=True)


def discover_nix() -> str | None:
    configured = os.environ.get("SEELE_FAILURE_NIX")
    if configured:
        return configured
    for candidate in (
        "/run/current-system/sw/bin/nix",
        "/nix/var/nix/profiles/default/bin/nix",
    ):
        if os.access(candidate, os.X_OK):
            return candidate
    return None


def nix_logs(entries: list[dict[str, object]]) -> list[tuple[str, str]]:
    messages = "\n".join(clean_text(entry.get("MESSAGE", ""), 4000) for entry in entries)
    derivations = list(dict.fromkeys(DRV_RE.findall(messages)))[:3]
    nix = discover_nix()
    if not nix:
        return []
    logs: list[tuple[str, str]] = []
    for derivation in derivations:
        result = run_capture([nix, "--offline", "log", derivation], timeout=20)
        output = result.stdout or result.stderr
        if output:
            logs.append((derivation, clean_text(bounded(output, 12 * 1024, tail=True), 14 * 1024)))
    return logs


def kernel_entries(entries: list[dict[str, object]]) -> list[dict[str, object]]:
    messages = "\n".join(clean_text(entry.get("MESSAGE", ""), 4000) for entry in entries)
    if not KERNEL_HINT_RE.search(messages):
        return []
    timestamps = [timestamp for entry in entries if (timestamp := journal_timestamp(entry)) is not None]
    if not timestamps:
        return []
    since = math.floor(min(timestamps) / 1_000_000) - 1
    until = math.ceil(max(timestamps) / 1_000_000) + 1
    result = run_capture(
        [
            executable("SEELE_FAILURE_JOURNALCTL", "journalctl"),
            "--no-pager",
            "--output=json",
            "--dmesg",
            "--priority=warning..alert",
            "--lines=40",
            f"--since=@{since}",
            f"--until=@{until}",
        ],
        timeout=10,
    )
    return parse_journal(result.stdout)


def collect_unit(unit: str) -> tuple[str, str]:
    if not UNIT_RE.fullmatch(unit) or unit.startswith("seele-failure-report@"):
        raise ValueError("invalid failed unit name")

    status = run_capture(
        [
            executable("SEELE_FAILURE_SYSTEMCTL", "systemctl"),
            "show",
            "--no-pager",
            *(f"--property={name}" for name in UNIT_PROPERTIES),
            unit,
        ],
        timeout=10,
    )
    properties = parse_properties(status.stdout)
    monitor_unit = os.environ.get("MONITOR_UNIT", "")
    monitor_invocation = os.environ.get("MONITOR_INVOCATION_ID", "")
    if monitor_unit == unit and INVOCATION_RE.fullmatch(monitor_invocation):
        # systemd captures these when it enqueues OnFailure=. Prefer that
        # immutable identity if the failed service has already restarted.
        properties["InvocationID"] = monitor_invocation.lower()
        for environment_name, property_name in (
            ("MONITOR_SERVICE_RESULT", "Result"),
            ("MONITOR_EXIT_CODE", "ExecMainCode"),
            ("MONITOR_EXIT_STATUS", "ExecMainStatus"),
        ):
            if value := os.environ.get(environment_name):
                properties[property_name] = clean_text(value, 100)
    invocation = properties.get("InvocationID", "")
    entries: list[dict[str, object]] = []
    if INVOCATION_RE.fullmatch(invocation):
        journal = run_capture(
            [
                executable("SEELE_FAILURE_JOURNALCTL", "journalctl"),
                "--no-pager",
                "--output=json",
                "--lines=80",
                f"_SYSTEMD_INVOCATION_ID={invocation.lower()}",
                "+",
                f"INVOCATION_ID={invocation.lower()}",
            ],
            timeout=15,
        )
        entries = parse_journal(journal.stdout)

    sections = [
        "Seele failure report",
        f"Collected: {datetime.now(timezone.utc).isoformat(timespec='seconds')}",
        f"Failed unit: {unit}",
        "",
        "[Unit state]",
    ]
    if properties:
        sections.extend(f"{name}={properties.get(name, '')}" for name in UNIT_PROPERTIES if name in properties)
    else:
        sections.append(clean_text(status.stderr or "systemctl returned no unit state", 4000))

    sections.extend(["", "[Journal for failed invocation]"])
    sections.append(format_journal(entries) if entries else "No journal entries were available for this invocation.")

    for derivation, log in nix_logs(entries):
        sections.extend(["", f"[Local Nix build log: {derivation}]", log])

    kernel = kernel_entries(entries)
    if kernel:
        sections.extend(["", "[Kernel warnings during failed invocation]", format_journal(kernel, 16 * 1024)])

    report = bounded("\n".join(sections).rstrip() + "\n", MAX_REPORT)
    result = properties.get("Result") or properties.get("SubState") or "failed"
    exit_status = properties.get("ExecMainStatus")
    last_message = ""
    for entry in reversed(entries):
        candidate = clean_text(entry.get("MESSAGE", ""), 300).replace("\n", " ")
        if candidate:
            last_message = candidate
            break
    summary = f"Result: {result}"
    if exit_status:
        summary += f" · exit {exit_status}"
    if last_message:
        summary += f"\n{last_message}"
    return report, bounded(summary, 420)


def runtime_directory() -> Path:
    configured = os.environ.get("XDG_RUNTIME_DIR")
    candidate = Path(configured) if configured else Path(f"/run/user/{os.getuid()}")
    metadata = candidate.stat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise RuntimeError("a private user runtime directory is unavailable")
    return candidate


def private_report_directory() -> Path:
    directory = runtime_directory() / "seele-shell" / "failures"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    metadata = directory.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise RuntimeError("failure report directory is not private")
    directory.chmod(0o700)
    now = datetime.now().timestamp()
    for child in directory.iterdir():
        try:
            child_metadata = child.lstat()
            if stat.S_ISREG(child_metadata.st_mode) and now - child_metadata.st_mtime > REPORT_LIFETIME_SECONDS:
                child.unlink()
        except OSError:
            continue
    return directory


def private_ai_directory() -> Path:
    directory = runtime_directory() / "seele-shell" / "failure-analysis"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    metadata = directory.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise RuntimeError("AI analysis directory is not private")
    directory.chmod(0o700)
    return directory


def create_report(report: str) -> tuple[str, Path]:
    directory = private_report_directory()
    for _ in range(8):
        report_id = secrets.token_hex(8)
        path = directory / f"{report_id}.txt"
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        except FileExistsError:
            continue
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(bounded(report, MAX_REPORT))
        return report_id, path
    raise RuntimeError("could not allocate a private failure report")


def report_path(report_id: str) -> Path:
    if not REPORT_ID_RE.fullmatch(report_id):
        raise ValueError("invalid report id")
    path = private_report_directory() / f"{report_id}.txt"
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise RuntimeError("failure report is not a private regular file")
    return path


def append_report(path: Path, heading: str, text: str) -> None:
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise RuntimeError("refusing to update an unsafe failure report")
    descriptor = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(f"\n\n[{heading}]\n{bounded(text.strip(), MAX_AI_OUTPUT)}\n")


def notify(title: str, body: str, actions: Sequence[tuple[str, str]]) -> str | None:
    arguments = [
        executable("SEELE_FAILURE_NOTIFY", "notify-send"),
        "--app-name=Seele",
        "--icon=dialog-error",
        "--expire-time=30000",
        "--transient",
    ]
    for name, label in actions:
        arguments.extend(["--action", f"{name}={label}"])
    arguments.extend(["--wait", clean_text(title, 100), clean_text(body, 800)])
    result = run_capture(arguments, timeout=35)
    if result.returncode != 0:
        return None
    choices = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return choices[-1] if choices else None


def known_secret_values() -> set[str]:
    values = {
        value
        for name, value in os.environ.items()
        if SECRET_NAME_RE.search(name) and len(value) >= 4
    }
    result = run_capture(
        [executable("SEELE_FAILURE_SYSTEMCTL", "systemctl"), "--user", "show-environment"],
        timeout=3,
    )
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            name, separator, value = line.partition("=")
            if separator and SECRET_NAME_RE.search(name) and len(value) >= 4:
                values.add(value)
    return values


def redact(report: str) -> str:
    redacted = report
    redacted = re.sub(
        r"-----BEGIN [^-\n]+-----.*?-----END [^-\n]+-----",
        "[REDACTED PRIVATE MATERIAL]",
        redacted,
        flags=re.DOTALL,
    )
    redacted = re.sub(
        r"(?im)^(\s*(?:authorization|proxy-authorization|cookie|set-cookie)\s*[:=]).*$",
        r"\1 [REDACTED]",
        redacted,
    )
    redacted = re.sub(
        r"(?i)([\"']?[A-Za-z0-9_.-]*(?:pass(?:word)?|token|secret|api[_-]?key|auth(?:entication|orization)?|cookie|credential|private[_-]?key)[A-Za-z0-9_.-]*[\"']?\s*[:=]\s*)(?:\"[^\"]*\"|'[^']*'|[^\s,;]+)",
        r"\1[REDACTED]",
        redacted,
    )
    redacted = re.sub(
        r"(?i)(--?(?:pass(?:word)?|token|secret|api[_-]?key|authorization|cookie|credential|private[_-]?key)(?:=|\s+))(?:\"[^\"]*\"|'[^']*'|[^\s,;]+)",
        r"\1[REDACTED]",
        redacted,
    )
    redacted = re.sub(r"\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{16,}|glpat-[A-Za-z0-9_-]{16,}|xox[baprs]-[A-Za-z0-9-]{16,})\b", "[REDACTED TOKEN]", redacted)
    redacted = re.sub(r"\bAKIA[0-9A-Z]{16}\b", "[REDACTED AWS KEY]", redacted)
    redacted = re.sub(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b", "[REDACTED JWT]", redacted)
    redacted = re.sub(r"(?i)\b([a-z][a-z0-9+.-]*://)[^/@\s]+@", r"\1[REDACTED]@", redacted)

    identifiers = set(known_secret_values())
    identifiers.update(filter(None, (os.environ.get("HOME"), os.environ.get("USER"), socket.gethostname())))
    machine_id = Path("/etc/machine-id")
    try:
        identifiers.add(machine_id.read_text(encoding="utf-8").strip())
    except OSError:
        pass
    for value in sorted((value for value in identifiers if len(value) >= 4), key=len, reverse=True):
        redacted = redacted.replace(value, "[REDACTED]")
    return redacted


def analyze_report(report: str) -> tuple[str | None, str | None]:
    safe_report = redact(report)
    prompt = (
        "A local service or NixOS operation crashed or failed. Check why using only the redacted "
        "failure report supplied on stdin. State the likely cause first, then give two to four concrete "
        "checks or fixes. Be concise and do not ask follow-up questions. The relevant declarative "
        f"configuration is at {os.environ.get('SEELE_FAILURE_CONFIG_REPO', '~/seele')}."
    )
    environment = os.environ.copy()
    environment["PI_SKIP_VERSION_CHECK"] = "1"
    result = run_capture(
        [
            executable("SEELE_FAILURE_PI", "pi"),
            "--print",
            "--no-session",
            "--no-tools",
            "--no-extensions",
            "--no-skills",
            "--no-prompt-templates",
            "--no-context-files",
            "--no-approve",
            prompt,
        ],
        input_text=safe_report,
        timeout=300,
        environment=environment,
        cwd=private_ai_directory(),
    )
    if result.returncode != 0:
        return None, bounded(clean_text(result.stderr or "Pi analysis failed", 4000), 4000)
    analysis = bounded(clean_text(result.stdout, MAX_AI_OUTPUT), MAX_AI_OUTPUT)
    return (analysis, None) if analysis else (None, "Pi returned no analysis")


def launch_view(path: Path, report_id: str) -> bool:
    unit = f"seele-failure-view-{report_id}-{secrets.token_hex(3)}"
    result = run_capture(
        [
            executable("SEELE_FAILURE_SYSTEMD_RUN", "systemd-run"),
            "--user",
            "--quiet",
            "--collect",
            f"--unit={unit}",
            "--service-type=exec",
            f"--setenv=SEELE_FAILURE_REPORT={path}",
            "--",
            executable("SEELE_FAILURE_GHOSTTY", "ghostty"),
            "--class=org.seele.failure",
            "-e",
            executable("SEELE_FAILURE_NVIM", "nvim"),
            "--clean",
            "-n",
            "-S",
            executable("SEELE_FAILURE_VIEW_LUA", "view.lua"),
        ],
        timeout=10,
    )
    return result.returncode == 0


def likely_cause(analysis: str) -> str:
    for line in analysis.splitlines():
        line = re.sub(r"^[#>*_`\-\d.)\s]+", "", line).strip()
        if line:
            return bounded(redact(line), 280)
    return "Pi returned an analysis without a summary line."


def store_offer(report: str, subject: str, summary: str) -> int:
    report_id, path = create_report(report)
    safe_subject = clean_text(subject, 100) or "System operation"
    safe_summary = bounded(redact(clean_text(summary, 500)), 420)
    action = notify(
        f"{safe_subject} failed",
        f"{safe_summary}\n\nAnalyze only sends a redacted copy to Pi.",
        (("analyze", "Analyze with AI"), ("view", "See error")),
    )
    if action == "view":
        if not launch_view(path, report_id):
            notify("Could not open failure report", f"Run: seele-failure-report view {report_id}", ())
        return 0
    if action != "analyze":
        return 0

    analysis, error = analyze_report(report)
    if error:
        safe_error = bounded(redact(error), 4000)
        append_report(path, "AI analysis error", safe_error)
        action = notify("AI analysis failed", f"{safe_error}\n\nRun: seele-failure-report view {report_id}", (("view", "See error"),))
        if action == "view":
            launch_view(path, report_id)
        return 1
    assert analysis is not None
    append_report(path, "AI analysis (explicitly requested)", analysis)
    action = notify(
        f"Likely cause · {safe_subject}",
        f"{likely_cause(analysis)}\n\nFull report: seele-failure-report view {report_id}",
        (("view", "View full report"),),
    )
    if action == "view":
        launch_view(path, report_id)
    return 0


def user_session_environment(user: pwd.struct_passwd) -> dict[str, str]:
    runtime = Path(f"/run/user/{user.pw_uid}")
    metadata = runtime.stat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != user.pw_uid:
        raise RuntimeError(f"{user.pw_name} has no active private runtime directory")
    profile = f"/etc/profiles/per-user/{user.pw_name}/bin"
    return {
        "HOME": user.pw_dir,
        "USER": user.pw_name,
        "LOGNAME": user.pw_name,
        "LANG": "C.UTF-8",
        "XDG_RUNTIME_DIR": str(runtime),
        "XDG_CONFIG_HOME": f"{user.pw_dir}/.config",
        "XDG_CACHE_HOME": f"{user.pw_dir}/.cache",
        "XDG_DATA_HOME": f"{user.pw_dir}/.local/share",
        "XDG_STATE_HOME": f"{user.pw_dir}/.local/state",
        "DBUS_SESSION_BUS_ADDRESS": f"unix:path={runtime}/bus",
        "PATH": f"{profile}:/run/current-system/sw/bin:/usr/bin:/bin",
    }


def offer_as_user(username: str, report: str, subject: str, summary: str) -> int:
    user = pwd.getpwnam(username)
    environment = user_session_environment(user)
    arguments = [
        executable("SEELE_FAILURE_RUNUSER", "runuser"),
        "--user",
        username,
        "--",
        executable("SEELE_FAILURE_ENV", "env"),
        "-i",
        *(f"{name}={value}" for name, value in environment.items()),
        executable("SEELE_FAILURE_SELF", "seele-failure-report"),
        "store-envelope",
    ]
    envelope = json.dumps({"report": report, "subject": subject, "summary": summary})
    result = run_capture(arguments, input_text=envelope, timeout=500)
    return result.returncode


def rebuild(arguments: Sequence[str]) -> int:
    nh_arguments = list(arguments) if list(arguments[:2]) == ["os", "switch"] else ["os", "switch", *arguments]
    command = [executable("SEELE_FAILURE_NH", "nh"), *nh_arguments]
    tail: deque[str] = deque(maxlen=180)
    try:
        process = subprocess.Popen(
            command,
            stdin=None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except OSError as error:
        output = str(error)
        returncode = 127
    else:
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            tail.append(line)
        returncode = process.wait()
        output = bounded("".join(tail), MAX_COMMAND_OUTPUT, tail=True)
    if returncode == 0:
        return 0

    report = (
        "Seele failure report\n"
        f"Collected: {datetime.now(timezone.utc).isoformat(timespec='seconds')}\n"
        f"Failed command: {' '.join(command)}\n"
        f"Exit status: {returncode}\n\n"
        "[Output from failed rebuild]\n"
        f"{clean_text(output, MAX_COMMAND_OUTPUT)}\n"
    )
    last_line = next((clean_text(line, 300) for line in reversed(tail) if line.strip()), f"Exit status: {returncode}")
    store_offer(report, "NixOS rebuild", f"Exit {returncode}\n{last_line}")
    return returncode


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="seele-failure-report")
    subcommands = result.add_subparsers(dest="command", required=True)
    collect = subcommands.add_parser("collect-unit")
    collect.add_argument("unit")
    collect.add_argument("username")
    offer = subcommands.add_parser("store-offer")
    offer.add_argument("--subject", required=True)
    offer.add_argument("--summary", required=True)
    subcommands.add_parser("store-envelope")
    view = subcommands.add_parser("view")
    view.add_argument("report_id")
    rebuild_parser = subcommands.add_parser("rebuild")
    rebuild_parser.add_argument("arguments", nargs=argparse.REMAINDER)
    return result


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    if arguments.command == "collect-unit":
        report, summary = collect_unit(arguments.unit)
        return offer_as_user(arguments.username, report, arguments.unit, summary)
    if arguments.command == "store-offer":
        return store_offer(sys.stdin.read(), arguments.subject, arguments.summary)
    if arguments.command == "store-envelope":
        envelope = json.load(sys.stdin)
        if not isinstance(envelope, dict):
            raise ValueError("invalid report envelope")
        report = envelope.get("report")
        subject = envelope.get("subject")
        summary = envelope.get("summary")
        if not all(isinstance(value, str) for value in (report, subject, summary)):
            raise ValueError("invalid report envelope")
        return store_offer(report, subject, summary)
    if arguments.command == "view":
        path = report_path(arguments.report_id)
        return 0 if launch_view(path, arguments.report_id) else 1
    if arguments.command == "rebuild":
        return rebuild(arguments.arguments)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, RuntimeError, ValueError) as error:
        print(f"seele-failure-report: {error}", file=sys.stderr)
        raise SystemExit(1)
