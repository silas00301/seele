"""Real bounded probes; a failed snapshot never means its findings recovered."""
import asyncio
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import time

SOURCES = ('systemd', 'backups', 'disk', 'flake', 'certificates', 'inputs')
SAFE = re.compile(r'^[A-Za-z0-9_.:@/-]{1,200}$')
UNIT = re.compile(r'^[A-Za-z0-9_.:@\\-]+\.service$')


class ProbeError(ValueError):
    """Public errors intentionally exclude subprocess output and local secrets."""


async def run(args, timeout=30, limit=262144):
    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(
            *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
            env={**os.environ, 'LC_ALL': 'C', 'TZ': 'UTC'}, start_new_session=True)
        async def read():
            output = bytearray()
            while True:
                chunk = await proc.stdout.read(8192)
                if not chunk:
                    break
                output.extend(chunk)
                if len(output) > limit:
                    raise ProbeError('probe_output_limit')
            await proc.wait()
            return proc.returncode, bytes(output).decode('utf-8', errors='replace')
        return await asyncio.wait_for(read(), timeout)
    except (OSError, asyncio.TimeoutError) as exc:
        raise ProbeError('probe_unavailable') from None
    finally:
        if proc and proc.returncode is None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            await proc.wait()


def report(key, title, explanation, details, urgency='soon', actions=None):
    if not SAFE.fullmatch(key):
        raise ProbeError('invalid_source_identity')
    return dict(key=key, title=title, explanation=explanation, details=details,
                urgency=urgency, lifecycle='ongoing', actions=actions or ['recheck'],
                diagnostic=details[:4096])


def scope(value):
    if value not in ('user', 'system'):
        raise ProbeError('invalid_service_scope')
    return ['--user'] if value == 'user' else ['--system']


async def checked(args, timeout=30):
    status, output = await run(args, timeout)
    if status:
        raise ProbeError('probe_failed')
    return output


async def systemd(cfg):
    data = json.loads(await checked(['systemctl', *scope(cfg.get('scope', 'system')),
                                    'list-units', '--all', '--state=failed', '--no-pager', '--json=short']))
    if not isinstance(data, list):
        raise ProbeError('invalid_service_snapshot')
    rows = []
    for unit in data:
        name = unit['unit']
        # Other failed unit types are useful findings too, but never passed as actions.
        if not SAFE.fullmatch(name):
            raise ProbeError('invalid_service_identity')
        rows.append(report(cfg.get('scope', 'system') + '/' + name, 'Failed system service', 'A systemd unit is in the failed state.',
                           'Unit: ' + name + '\nState: failed', actions=['recheck', 'open-logs']))
    return rows


async def backups(cfg):
    rows = []
    for item in cfg.get('items', []):
        unit = item['unit']
        if not UNIT.fullmatch(unit):
            raise ProbeError('invalid_backup_unit')
        text = await checked(['systemctl', *scope(item.get('scope', 'user')), 'show', '--timestamp=unix',
                              '--property=LoadState,ActiveState,Result,ExecMainStatus,ExecMainExitTimestamp', '--', unit])
        state = dict(line.split('=', 1) for line in text.splitlines() if '=' in line)
        if not {'LoadState', 'ActiveState', 'Result', 'ExecMainStatus', 'ExecMainExitTimestamp'} <= state.keys():
            raise ProbeError('invalid_backup_snapshot')
        if state.get('LoadState') != 'loaded':
            raise ProbeError('backup_unit_unavailable')
        failed = state.get('ActiveState') == 'failed' or state.get('Result') not in ('success', '')
        failed = failed or state.get('ExecMainStatus', '0') != '0'
        if failed:
            rows.append(report(item['id'], item['label'] + ': backup failed',
                               'The configured backup service did not finish successfully.',
                               'Unit: ' + unit + '\nLatest service outcome: failed', 'soon',
                               ['recheck', 'open-logs', 'retry']))
            continue
        timestamp = 0.0
        marker = item.get('successFile')
        if marker:
            try:
                timestamp = Path(marker).stat().st_mtime
            except FileNotFoundError:
                pass
        else:
            value = state.get('ExecMainExitTimestamp', '')
            if value and value != 'n/a':
                if not re.fullmatch(r'@?[0-9]+(?:\.[0-9]+)?', value):
                    raise ProbeError('invalid_backup_timestamp')
                timestamp = float(value.lstrip('@'))
        age = time.time() - timestamp if timestamp else None
        if age is not None and age < -300:
            raise ProbeError('invalid_backup_timestamp')
        if age is None or age > item.get('maxAgeHours', 24) * 3600:
            detail = 'Unit: ' + unit + '\n'
            detail += ('No recorded successful completion.' if age is None else
                       'Last successful completion: ' + datetime.datetime.fromtimestamp(timestamp, datetime.timezone.utc).isoformat())
            rows.append(report(item['id'], item['label'] + ': backup overdue',
                               'No sufficiently recent successful backup is recorded.', detail,
                               'soon', ['recheck', 'open-logs', 'retry']))
    return rows


async def disk(cfg):
    rows = []
    soon, now = cfg.get('soonPercent', 85), cfg.get('nowPercent', 95)
    if not 0 < soon < now <= 100:
        raise ProbeError('invalid_disk_thresholds')
    for path in cfg.get('paths', ['/']):
        stat = await asyncio.to_thread(os.statvfs, path)
        if stat.f_blocks <= 0:
            raise ProbeError('invalid_disk_capacity')
        # Available space respects reserved filesystem blocks for this user.
        percent = (1 - stat.f_bavail / stat.f_blocks) * 100
        inode_percent = (1 - stat.f_favail / stat.f_files) * 100 if stat.f_files else 0
        severity = max(percent, inode_percent)
        if severity >= soon:
            key = hashlib.sha256(os.fsencode(path)).hexdigest()[:16]
            # Threshold bands are stable; live fluctuating byte counters would retrigger alerts.
            details = 'Filesystem: ' + str(path) + '\n'
            details += ('Available space below critical threshold.' if percent >= now else
                        'Available space below warning threshold.' if percent >= soon else 'Available space within threshold.')
            details += ('\nAvailable inodes below critical threshold.' if inode_percent >= now else
                        '\nAvailable inodes below warning threshold.' if inode_percent >= soon else '')
            rows.append(report(key, 'Disk space pressure', 'Free filesystem capacity is below the configured threshold.',
                               details, 'now' if severity >= now else 'soon'))
    return rows


async def flake(cfg):
    path = cfg['path']
    if not Path(path, 'flake.nix').is_file():
        raise ProbeError('flake_unavailable')
    status, _ = await run(['nix', 'flake', 'check', '--no-build', '--no-write-lock-file', '--', path], timeout=900)
    if not status:
        return []
    return [report('check', 'Flake checks failed', 'The configured flake failed its evaluation checks.',
                   'Command: nix flake check --no-build --no-write-lock-file\nExit status: ' + str(status), 'soon')]


async def certificates(cfg):
    rows = []
    for item in cfg.get('items', []):
        now_days, soon_days = item.get('nowDays', 7), item.get('soonDays', 30)
        if not 0 <= now_days < soon_days:
            raise ProbeError('invalid_certificate_thresholds')
        output = await checked(['openssl', 'x509', '-in', item['path'], '-noout', '-enddate'])
        if not output.startswith('notAfter='):
            raise ProbeError('invalid_certificate')
        expires = datetime.datetime.strptime(output.strip()[9:], '%b %d %H:%M:%S %Y %Z').replace(tzinfo=datetime.timezone.utc)
        remaining = (expires.timestamp() - time.time()) / 86400
        if remaining <= soon_days:
            rows.append(report(item['id'], item['label'] + ': certificate expiring',
                               'A configured certificate is nearing or past its expiration.',
                               'Certificate expires: ' + expires.isoformat(), 'now' if remaining <= now_days else 'soon'))
    return rows


def original_ref(original):
    # Construct only known public flake-reference shapes; never put auth/query material in argv.
    kind = original.get('type')
    if kind in ('github', 'gitlab'):
        pieces = [original.get('owner'), original.get('repo')]
        if original.get('dir') or original.get('host'):
            raise ProbeError('unsupported_input_reference')
        revision = original.get('rev') or original.get('ref')
        if revision:
            pieces.append(revision)
        if any(not isinstance(p, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*', p) for p in pieces):
            raise ProbeError('unsupported_input_reference')
        return kind + ':' + '/'.join(pieces)
    raise ProbeError('unsupported_input_reference')


async def inputs(cfg):
    path = Path(cfg['path'], 'flake.lock')
    if path.stat().st_size > 4 * 1024 * 1024:
        raise ProbeError('lock_file_too_large')
    lock = json.loads(path.read_text())
    nodes = lock['nodes']
    root = nodes[lock['root']]
    rows = []
    for item in cfg.get('items', []):
        name = item['id']
        target = root['inputs'][name]
        if not isinstance(target, str):
            raise ProbeError('unsupported_input_follow')
        node = nodes[target]
        pinned = node['locked']
        timestamp = pinned.get('lastModified')
        if type(timestamp) not in (int, float) or not math.isfinite(timestamp) or timestamp <= 0:
            raise ProbeError('input_age_unavailable')
        if time.time() - timestamp <= item.get('maxAgeDays', 30) * 86400:
            continue
        reference = original_ref(node['original'])
        metadata = json.loads(await checked(['nix', 'flake', 'metadata', '--json', '--no-write-lock-file',
                                            '--refresh', '--', reference], timeout=180))
        latest = metadata.get('locked', {}).get('rev') or metadata.get('revision')
        if not isinstance(latest, str) or not re.fullmatch(r'[0-9a-fA-F]{7,64}', latest):
            raise ProbeError('input_revision_unavailable')
        current = pinned.get('rev')
        if not isinstance(current, str) or not re.fullmatch(r'[0-9a-fA-F]{7,64}', current):
            raise ProbeError('input_revision_unavailable')
        if latest != current:
            rows.append(report(name, name + ': critical input outdated',
                               'A configured critical input exceeds its age threshold and a newer upstream revision is available.',
                               'Input: ' + name + '\nPinned revision: ' + current + '\nAvailable revision: ' + latest,
                               'eventually'))
    return rows


async def collect(config, source):
    if source not in SOURCES:
        raise ProbeError('unknown_source')
    cfg = config.get(source, {})
    if not cfg.get('enabled', True):
        return []
    try:
        return await globals()[source](cfg)
    except ProbeError:
        raise
    except (OSError, ValueError, TypeError, KeyError, OverflowError):
        raise ProbeError('probe_unavailable') from None
