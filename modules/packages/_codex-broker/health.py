#!/usr/bin/env python3
"""Broker-owned health heartbeat. Never infer or retain authentication output."""
import json
import os
import socket
import subprocess
import time

LIMIT = 256 * 1024


def probe(path):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(5)
            connection.connect(path)
            connection.sendall(b'{"op":"list"}\n')
            with connection.makefile('rb') as stream:
                raw = stream.readline(LIMIT + 1)
            if len(raw) > LIMIT:
                return False
            result = json.loads(raw)
            return isinstance(result, dict) and result.get('ok') is True
    except (OSError, ValueError):
        return False


def run(argv, payload=None):
    try:
        return subprocess.run(argv, input=payload, stdin=subprocess.DEVNULL if payload is None else None,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              timeout=8, check=False).returncode
    except (OSError, subprocess.TimeoutExpired):
        return None


def snapshot(path, binary, rpc=probe, execute=run, clock=time.time):
    value = {'state': 'disconnected', 'summary': 'Broker unavailable', 'detail': 'The inference service is not responding.',
             'lastSuccess': 0, 'actions': ['restart', 'diagnostics']}
    if not rpc(path):
        return value
    result = execute([binary, 'login', 'status'])
    if result is None:
        value.update(summary='Codex unavailable', detail='The configured Codex application could not be checked.')
    elif result != 0:
        value.update(state='setup-required', summary='Sign in to Codex', detail='Open a terminal and run codex login to connect your account.')
    else:
        value.update(state='healthy', summary='Ready for requests', detail='', lastSuccess=int(clock() * 1000))
    return value


def main():
    runtime = os.environ.get('XDG_RUNTIME_DIR', '/nonexistent')
    binary = os.environ.get('SEELE_BROKER_CODEX', 'codex')
    value = snapshot(os.path.join(runtime, 'seele-codex.sock'), binary)
    # The shell helper owns its configured IPC path. No shell commands or private
    # broker/job/authentication fields are copied into the shared health payload.
    run(['seele-shellctl', 'health-publish', 'codex'], json.dumps(value).encode())


if __name__ == '__main__':
    main()
