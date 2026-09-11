"""Typed maintenance lifecycle. Persisted records never include diagnostic or AI data."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import time

URGENCY = {'now': 0, 'soon': 1, 'eventually': 2, 'informational': 3}
KEY = re.compile(r'^[A-Za-z0-9_.:@/-]{1,200}$')
WEEK = 7 * 86400


def clean(value, limit=1000):
    value = str(value)
    value = re.sub(r'-----BEGIN .*?-----[\s\S]*?-----END .*?-----', '[redacted key]', value)
    value = re.sub(r'(?i)\b(token|password|secret|authorization|cookie|api[_-]?key)\s*[:=]\s*\S+', r'\1=[redacted]', value)
    value = re.sub(r'(?i)\b(?:bearer\s+\S+|(?:gh[opusr]_|sk-)[A-Za-z0-9_-]+)', '[redacted]', value)
    value = re.sub(r'https?://\S+', '[link omitted]', value)
    return ''.join(c for c in value if ord(c) >= 32 or c == '\n')[:limit]


class Invalid(ValueError):
    pass


class Inbox:
    def __init__(self, registrations, path=None, clock=time.time):
        self.registrations, self.path, self.clock = registrations, path, clock
        self.items, self.diagnostics, self.analysis = {}, {}, {}
        if path and Path(path).exists():
            try:
                if Path(path).stat().st_size > 16 * 1024 * 1024:
                    raise ValueError('state_too_large')
                saved = json.loads(Path(path).read_text())
                if not isinstance(saved, list) or len(saved) > 4096:
                    raise ValueError('invalid_state')
                for raw in saved:
                    try:
                        source, key = raw['source'], raw['key']
                        if source not in registrations or not isinstance(key, str) or not KEY.fullmatch(key):
                            continue
                        if raw['urgency'] not in URGENCY or raw['lifecycle'] not in ('ongoing', 'notice'):
                            continue
                        if not isinstance(raw['actions'], list) or not all(isinstance(a, str) for a in raw['actions']):
                            continue
                        row = dict(id=source + ':' + key, source=source, key=key, busy='',
                                   urgency=raw['urgency'], lifecycle=raw['lifecycle'])
                        for field in ('firstSeen', 'updated', 'snoozedUntil', 'resolved'):
                            value = raw[field]
                            if type(value) not in (float, int) or not math.isfinite(value) or value < 0:
                                raise ValueError('invalid_timestamp')
                            row[field] = value
                        for field in ('revision', 'recurrence'):
                            if type(raw[field]) is not int or raw[field] < 0:
                                raise ValueError('invalid_revision')
                            row[field] = raw[field]
                        if any(not isinstance(raw.get(field), str) for field in ('title', 'explanation', 'details')):
                            continue
                        fingerprint = raw.get('fingerprint', '')
                        if not isinstance(fingerprint, str) or not re.fullmatch(r'[0-9a-f]{64}', fingerprint):
                            fingerprint = ''
                        row.update(title=clean(raw['title'],160), explanation=clean(raw['explanation'],500),
                                   details=clean(raw['details'],2000), fingerprint=fingerprint,
                                   actions=[a for a in raw['actions'] if a in registrations[source]['actions']], outcomes=[])
                        for outcome in raw.get('outcomes', [])[-20:]:
                            if (outcome.get('action') in {*registrations[source]['actions'], 'analyze'}
                                    and type(outcome.get('at')) in (int, float) and math.isfinite(outcome['at'])):
                                row['outcomes'].append(dict(action=outcome['action'], at=outcome['at'],
                                                            result=clean(outcome.get('result',''),160)))
                        self.items[row['id']] = row
                    except (ValueError, KeyError, TypeError, AttributeError):
                        continue
            except (OSError, ValueError, KeyError, TypeError):
                self.items = {}
        self.prune()

    def prune(self):
        cutoff = self.clock() - WEEK
        for identity, item in list(self.items.items()):
            if item['source'] not in self.registrations or (item['resolved'] and item['resolved'] < cutoff):
                self.items.pop(identity, None)
                self.diagnostics.pop(identity, None)
                self.analysis.pop(identity, None)

    def persist(self):
        self.prune()
        if not self.path:
            return
        path = Path(self.path)
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(path.parent, 0o700)
        # Only contract metadata; diagnostics, analysis and model output never reach disk.
        value = []
        for item in self.items.values():
            row = copy.deepcopy(item)
            row['busy'] = ''
            value.append(row)
        temp = path.with_suffix('.tmp')
        fd = os.open(temp, os.O_CREAT | os.O_TRUNC | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)

    def publish(self, source, report):
        if source not in self.registrations or not isinstance(report, dict):
            raise Invalid('unregistered_source')
        allowed = {'key', 'title', 'explanation', 'details', 'urgency', 'lifecycle', 'actions', 'diagnostic'}
        if set(report) - allowed or not isinstance(report.get('key'), str) or not KEY.fullmatch(report['key']):
            raise Invalid('invalid_finding')
        urgency, lifecycle = report.get('urgency'), report.get('lifecycle', 'ongoing')
        if not isinstance(urgency, str) or urgency not in URGENCY or lifecycle not in ('ongoing', 'notice'):
            raise Invalid('invalid_finding')
        actions = report.get('actions', [])
        if not isinstance(actions, list) or any(not isinstance(a, str) or a not in self.registrations[source]['actions'] for a in actions):
            raise Invalid('unregistered_action')
        if any(not isinstance(report.get(k, ''), str) for k in ('title', 'explanation', 'details')):
            raise Invalid('invalid_finding')
        content = dict(title=clean(report.get('title', ''), 160), explanation=clean(report.get('explanation', ''), 500),
                       details=clean(report.get('details', ''), 2000), urgency=urgency, lifecycle=lifecycle, actions=actions)
        if not content['title']:
            raise Invalid('invalid_finding')
        diagnostic = report.get('diagnostic')
        if diagnostic is not None:
            if not isinstance(diagnostic, str) or len(diagnostic.encode()) > 16384:
                raise Invalid('diagnostic_too_large')
            diagnostic = clean(diagnostic, 16384)
        identity = source + ':' + report['key']
        previous = self.items.get(identity)
        if previous is None and len(self.items) >= 4096:
            raise Invalid('capacity')
        signature = hashlib.sha256(json.dumps([content, diagnostic], sort_keys=True).encode()).hexdigest()
        changed = not previous or previous['fingerprint'] != signature or bool(previous['resolved'])
        now = self.clock()
        row = dict(previous or dict(id=identity, source=source, key=report['key'], firstSeen=now, updated=now,
                                    revision=0, recurrence=0, snoozedUntil=0, resolved=0, outcomes=[], busy=''))
        if previous and previous['resolved']:
            row['recurrence'] += 1
        if previous and URGENCY[urgency] < URGENCY[previous['urgency']]:
            row['snoozedUntil'] = 0
        row.update(content, fingerprint=signature, resolved=0)
        if changed:
            row['updated'] = now
            row['revision'] += 1
        self.items[identity] = row
        if diagnostic is not None:
            self.diagnostics[identity] = diagnostic
        else:
            self.diagnostics.pop(identity, None)
        self.persist()
        return row, changed and urgency in ('now', 'soon') and row['snoozedUntil'] <= now

    def resolve(self, source, key):
        if source not in self.registrations:
            raise Invalid('unregistered_source')
        row = self.items.get(source + ':' + key)
        if row and not row['resolved']:
            row['resolved'] = self.clock()
            row['busy'] = ''
            self.diagnostics.pop(row['id'], None)
            self.analysis.pop(row['id'], None)
            self.persist()

    def operation(self, identity, revision, operation, seconds=0):
        row = self.items.get(identity)
        if not row or row['resolved'] or row['revision'] != revision:
            raise Invalid('stale_finding')
        if operation == 'done':
            if row['lifecycle'] != 'notice':
                raise Invalid('publisher_owned_condition')
            self.resolve(row['source'], row['key'])
        elif operation == 'snooze':
            if type(seconds) is not int or not 60 <= seconds <= 30 * 86400:
                raise Invalid('invalid_duration')
            row['snoozedUntil'] = self.clock() + seconds
        elif operation == 'unsnooze':
            row['snoozedUntil'] = 0
        else:
            raise Invalid('invalid_operation')
        self.persist()

    def snapshot(self):
        self.prune()
        now = self.clock()
        rows = []
        for value in self.items.values():
            row = copy.deepcopy(value)
            row.pop('fingerprint', None)
            row['canAnalyze'] = row['id'] in self.diagnostics and not row['resolved']
            row['analysis'] = self.analysis.get(row['id'])
            row['analysisStale'] = bool(row['analysis'] and row['analysis']['revision'] != row['revision'])
            row['actions'] = [dict(id=a, label=self.registrations[row['source']]['actions'][a]['label'],
                                   disruptive=self.registrations[row['source']]['actions'][a].get('disruptive', False)) for a in row['actions']]
            rows.append(row)
        active = sorted((r for r in rows if not r['resolved'] and r['snoozedUntil'] <= now), key=lambda r:(URGENCY[r['urgency']], -r['updated']))
        snoozed = sorted((r for r in rows if not r['resolved'] and r['snoozedUntil'] > now), key=lambda r:r['snoozedUntil'])
        history = sorted((r for r in rows if r['resolved']), key=lambda r:-r['resolved'])
        attention = [r for r in active if r['urgency'] != 'informational']
        return dict(active=active, snoozed=snoozed, history=history, count=len(attention), urgency=attention[0]['urgency'] if attention else '')
