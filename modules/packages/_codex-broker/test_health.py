import json
import subprocess
import unittest
from unittest.mock import patch
import health


class Tests(unittest.TestCase):
    def test_missing_service_does_not_read_authentication(self):
        def forbidden(*args):
            self.fail('unavailable broker should not inspect Codex login')
        state = health.snapshot('/private/socket', '/codex', rpc=lambda path: False, execute=forbidden)
        self.assertEqual(state['state'], 'disconnected')
        self.assertEqual(state['lastSuccess'], 0)

    def test_authentication_output_never_enters_payload(self):
        calls = []
        def execute(argv):
            calls.append(argv)
            return 1
        state = health.snapshot('/private/socket', '/codex', rpc=lambda path: True, execute=execute)
        self.assertEqual(calls, [['/codex', 'login', 'status']])
        self.assertEqual(state['state'], 'setup-required')
        self.assertEqual(state['actions'], ['restart', 'diagnostics'])
        self.assertNotIn('/private/socket', json.dumps(state))

    def test_success_is_timestamped_and_cli_failure_is_not_auth_failure(self):
        healthy = health.snapshot('socket', 'codex', rpc=lambda path: True, execute=lambda argv: 0, clock=lambda: 123)
        self.assertEqual(healthy['state'], 'healthy')
        self.assertEqual(healthy['lastSuccess'], 123000)
        missing = health.snapshot('socket', 'codex', rpc=lambda path: True, execute=lambda argv: None)
        self.assertEqual(missing['state'], 'disconnected')

    def test_subprocess_output_is_discarded_and_timeout_is_bounded(self):
        with patch.object(subprocess, 'run') as runner:
            runner.return_value.returncode = 0
            self.assertEqual(health.run(['codex', 'login', 'status']), 0)
            self.assertEqual(runner.call_args.kwargs['stdout'], subprocess.DEVNULL)
            self.assertEqual(runner.call_args.kwargs['stderr'], subprocess.DEVNULL)
            self.assertEqual(runner.call_args.kwargs['stdin'], subprocess.DEVNULL)
            self.assertEqual(runner.call_args.kwargs['timeout'], 8)
            runner.side_effect = subprocess.TimeoutExpired('codex', 8)
            self.assertIsNone(health.run(['codex', 'login', 'status']))

    def test_publish_uses_stdin_and_fixed_target(self):
        with patch.object(health, 'snapshot', return_value={'state':'healthy'}) as snapshot, patch.object(health, 'run') as run:
            health.main()
            self.assertEqual(run.call_args.args[0], ['seele-shellctl', 'health-publish', 'codex'])
            self.assertEqual(json.loads(run.call_args.args[1]), {'state':'healthy'})


if __name__ == '__main__':
    unittest.main()
