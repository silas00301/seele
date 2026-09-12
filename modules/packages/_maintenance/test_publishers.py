import asyncio
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

import publishers as p


class Publishers(unittest.IsolatedAsyncioTestCase):
    async def test_failed_units_and_probe_failure_are_distinct(self):
        with patch.object(p, 'run', AsyncMock(return_value=(0, '[{"unit":"example.service"}]'))) as run:
            rows = await p.collect({'systemd': {'scope': 'user'}}, 'systemd')
            self.assertEqual(rows[0]['key'], 'user/example.service')
            self.assertEqual(rows[0]['actions'], ['recheck', 'open-logs'])
            self.assertIn('--user', run.call_args.args[0])
        with patch.object(p, 'run', AsyncMock(return_value=(0, '[]'))):
            self.assertEqual(await p.collect({}, 'systemd'), [])
        for response in [(1, 'token=secret'), (0, 'token=secret')]:
            with patch.object(p, 'run', AsyncMock(return_value=response)):
                with self.assertRaises(p.ProbeError) as caught:
                    await p.collect({}, 'systemd')
                self.assertNotIn('secret', str(caught.exception))

    async def test_backup_failure_stale_success_and_missing_unit(self):
        cfg = {'backups': {'items': [dict(id='vault', label='Vault', unit='vault.service',
                                         maxAgeHours=24, scope='user')]}}
        def state(result='success', exit='0', timestamp='@100000', active='inactive', load='loaded'):
            return '\n'.join(['LoadState='+load, 'ActiveState='+active, 'Result='+result,
                              'ExecMainStatus='+exit, 'ExecMainExitTimestamp='+timestamp])
        with patch.object(p.time, 'time', return_value=100100):
            with patch.object(p, 'run', AsyncMock(return_value=(0, state()))):
                self.assertEqual(await p.collect(cfg, 'backups'), [])
            with patch.object(p, 'run', AsyncMock(return_value=(0, state('exit-code', '1')))):
                rows = await p.collect(cfg, 'backups')
                self.assertIn('failed', rows[0]['title'])
                self.assertEqual(rows[0]['key'], 'vault')
                self.assertIn('retry', rows[0]['actions'])
            with patch.object(p, 'run', AsyncMock(return_value=(0, state(timestamp='')))):
                rows = await p.collect(cfg, 'backups')
                self.assertIn('overdue', rows[0]['title'])
            with patch.object(p, 'run', AsyncMock(return_value=(0, state(load='not-found')))):
                with self.assertRaises(p.ProbeError):
                    await p.collect(cfg, 'backups')
        with patch.object(p, 'run', AsyncMock(return_value=(0, state()))), patch.object(p.time, 'time', return_value=300000):
            stale = await p.collect(cfg, 'backups')
        with patch.object(p, 'run', AsyncMock(return_value=(0, state()))), patch.object(p.time, 'time', return_value=300060):
            self.assertEqual(stale, await p.collect(cfg, 'backups'))

    async def test_backup_success_marker_survives_absent_boot_timestamp(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory, 'success')
            marker.touch()
            cfg = {'backups': {'items': [dict(id='vault', label='Vault', unit='vault.service', successFile=str(marker))]}}
            text = 'LoadState=loaded\nActiveState=inactive\nResult=success\nExecMainStatus=0\nExecMainExitTimestamp=\n'
            with patch.object(p, 'run', AsyncMock(return_value=(0, text))):
                self.assertEqual(await p.collect(cfg, 'backups'), [])

    async def test_disk_pressure_inodes_thresholds_and_stable_snapshot(self):
        class Stat:
            f_blocks, f_bavail, f_files, f_favail = 1000, 100, 100, 100
        with patch.object(p.os, 'statvfs', return_value=Stat()):
            warning = await p.collect({'disk': {'paths': ['/data']}}, 'disk')
            self.assertEqual(warning[0]['urgency'], 'soon')
            Stat.f_bavail = 99
            self.assertEqual(warning, await p.collect({'disk': {'paths': ['/data']}}, 'disk'))
            Stat.f_favail = 1
            critical = await p.collect({'disk': {'paths': ['/data']}}, 'disk')
            self.assertEqual(critical[0]['urgency'], 'now')
            self.assertEqual(critical[0]['key'], warning[0]['key'])
            Stat.f_bavail, Stat.f_favail = 500, 100
            self.assertEqual(await p.collect({}, 'disk'), [])
        with patch.object(p.os, 'statvfs', side_effect=PermissionError('private path')):
            with self.assertRaisesRegex(p.ProbeError, '^probe_unavailable$'):
                await p.collect({}, 'disk')

    async def test_flake_real_command_flags_and_failed_check(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, 'flake.nix').write_text('{}')
            cfg = {'flake': {'path': directory}}
            with patch.object(p, 'run', AsyncMock(return_value=(1, 'password=secret'))) as run:
                rows = await p.collect(cfg, 'flake')
                self.assertIn('--no-write-lock-file', run.call_args.args[0])
                self.assertIn('--no-build', run.call_args.args[0])
                self.assertNotIn('secret', json.dumps(rows))
            with patch.object(p, 'run', AsyncMock(return_value=(0, ''))):
                self.assertEqual(await p.collect(cfg, 'flake'), [])

    async def test_certificate_expiry_is_stable_and_bad_cert_is_not_recovery(self):
        cfg = {'certificates': {'items': [dict(id='local', label='Local', path='/certificate.pem')]}}
        expiry = p.datetime.datetime(2026, 10, 1, tzinfo=p.datetime.timezone.utc).timestamp()
        with patch.object(p, 'run', AsyncMock(return_value=(0, 'notAfter=Oct  1 00:00:00 2026 GMT\n'))):
            with patch.object(p.time, 'time', return_value=expiry-15*86400):
                rows = await p.collect(cfg, 'certificates')
                self.assertEqual(rows[0]['urgency'], 'soon')
            with patch.object(p.time, 'time', return_value=expiry-14*86400):
                self.assertEqual(rows, await p.collect(cfg, 'certificates'))
            with patch.object(p.time, 'time', return_value=expiry-86400):
                self.assertEqual((await p.collect(cfg, 'certificates'))[0]['urgency'], 'now')
            with patch.object(p.time, 'time', return_value=expiry-60*86400):
                self.assertEqual(await p.collect(cfg, 'certificates'), [])
        with patch.object(p, 'run', AsyncMock(return_value=(1, 'private key content'))):
            with self.assertRaisesRegex(p.ProbeError, '^probe_failed$'):
                await p.collect(cfg, 'certificates')

    async def test_input_age_and_revision_both_required_without_rewriting_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            lock = Path(directory, 'flake.lock')
            value = dict(root='root', nodes={
                'root': {'inputs': {'nixpkgs': 'nixpkgs'}},
                'nixpkgs': {'locked': {'rev': 'a'*40, 'lastModified': 100000},
                            'original': {'type': 'github', 'owner': 'NixOS', 'repo': 'nixpkgs', 'ref': 'nixos-unstable'}}})
            lock.write_text(json.dumps(value))
            before = lock.read_bytes()
            cfg = {'inputs': {'path': directory, 'items': [{'id': 'nixpkgs', 'maxAgeDays': 30}]}}
            with patch.object(p.time, 'time', return_value=100000+31*86400):
                with patch.object(p, 'run', AsyncMock(return_value=(0, json.dumps({'locked': {'rev': 'b'*40}})))) as run:
                    rows = await p.collect(cfg, 'inputs')
                    self.assertEqual(rows[0]['urgency'], 'eventually')
                    self.assertEqual(rows[0]['key'], 'nixpkgs')
                    self.assertIn('--no-write-lock-file', run.call_args.args[0])
                    self.assertIn('github:NixOS/nixpkgs/nixos-unstable', run.call_args.args[0])
                with patch.object(p, 'run', AsyncMock(return_value=(0, json.dumps({'locked': {'rev': 'a'*40}})))):
                    self.assertEqual(await p.collect(cfg, 'inputs'), [])
                with patch.object(p, 'run', AsyncMock(return_value=(1, 'auth secret'))):
                    with self.assertRaises(p.ProbeError):
                        await p.collect(cfg, 'inputs')
            with patch.object(p.time, 'time', return_value=100100), patch.object(p, 'run', AsyncMock()) as run:
                self.assertEqual(await p.collect(cfg, 'inputs'), [])
                run.assert_not_called()
            self.assertEqual(lock.read_bytes(), before)

    async def test_explicit_input_revision_is_not_floated(self):
        value = dict(type='github', owner='NixOS', repo='nixpkgs', ref='unstable', rev='a'*40)
        self.assertEqual(p.original_ref(value), 'github:NixOS/nixpkgs/' + 'a'*40)
        for extra in ({'host': 'private.invalid'}, {'dir': 'nested'}, {'owner': 'secret@host'}):
            with self.assertRaises(p.ProbeError):
                p.original_ref({**value, **extra})

    async def test_empty_sources_and_disabled_probes(self):
        for source in ('backups', 'certificates'):
            self.assertEqual(await p.collect({}, source), [])
        with patch.object(p, 'run', AsyncMock()) as run:
            self.assertEqual(await p.collect({'flake': {'enabled': False}}, 'flake'), [])
            run.assert_not_called()

    async def test_subprocess_bounds_timeout_and_stderr_privacy(self):
        status, output = await p.run([sys.executable, '-c', 'import sys; print("ok"); print("secret",file=sys.stderr)'])
        self.assertEqual((status, output), (0, 'ok\n'))
        with self.assertRaisesRegex(p.ProbeError, '^probe_output_limit$'):
            await p.run([sys.executable, '-c', 'print("x"*10000)'], limit=100)
        with self.assertRaisesRegex(p.ProbeError, '^probe_unavailable$'):
            await p.run([sys.executable, '-c', 'import time; time.sleep(10)'], timeout=0.05)


if __name__ == '__main__':
    unittest.main()
