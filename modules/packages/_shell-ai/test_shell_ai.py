#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest import mock


SOURCE = Path(sys.argv.pop(1) if len(sys.argv) > 1 else Path(__file__).with_name("shell_ai.py"))
FEATURE = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else None
SPEC = importlib.util.spec_from_file_location("shell_ai", SOURCE)
assert SPEC is not None and SPEC.loader is not None
shell_ai = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shell_ai)


class ShellAiTests(unittest.TestCase):
    def executable(self, directory: Path, name: str, contents: str) -> Path:
        path = directory / name
        path.write_text(textwrap.dedent(contents).lstrip())
        path.chmod(0o755)
        return path

    def test_context_is_bounded_and_does_not_read_sensitive_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            commands = root / "bin"
            commands.mkdir()
            self.executable(commands, "jj", "#!/bin/sh\nexit 0\n")
            (commands / "not-executable").write_text("no")
            (root / "visible.txt").write_text("visible contents must not be collected")
            (root / ".env").write_text("API_TOKEN=TOP_SECRET")
            (root / "credentials.json").write_text("TOP_SECRET")
            (root / ".jj").mkdir()
            environment = {
                "PATH": str(commands),
                "IN_NIX_SHELL": "pure",
                "DIRENV_DIR": "/private/value",
                "API_TOKEN": "TOP_SECRET",
            }

            context = shell_ai.collect_context(root, environment)
            encoded = json.dumps(context)
            self.assertEqual(context["repository"], "jujutsu")
            self.assertIn("visible.txt", context["directory_listing"])
            self.assertNotIn(".env", context["directory_listing"])
            self.assertNotIn("credentials.json", context["directory_listing"])
            self.assertEqual(context["available_commands"]["sample"], ["jj"])
            self.assertEqual(context["active_dev_shell"]["nix_shell"], "pure")
            self.assertTrue(context["active_dev_shell"]["direnv"])
            self.assertNotIn("TOP_SECRET", encoded)
            self.assertNotIn("visible contents", encoded)
            self.assertNotIn("/private/value", encoded)
            empty_context = shell_ai.collect_context(root, {})
            self.assertEqual(empty_context["available_commands"]["sample"], [])

    def test_response_parser_accepts_fences_and_rejects_multiline_commands(self) -> None:
        suggestions = shell_ai.parse_suggestions(
            """```json
            {"suggestions":[{"command":"jj status","description":"Inspect the checkout","destructive":false}]}
            ```"""
        )
        self.assertEqual(suggestions[0]["command"], "jj status")
        self.assertFalse(suggestions[0]["destructive"])
        with self.assertRaises(shell_ai.UserError):
            shell_ai.parse_suggestions(
                '{"suggestions":[{"command":"printf one\\nprintf two","description":"two lines"}]}'
            )
        for unsafe_command in ("jj\tstatus", "jj status\u202estatus"):
            with self.subTest(command=unsafe_command):
                with self.assertRaises(shell_ai.UserError):
                    shell_ai.parse_suggestions(
                        json.dumps({"suggestions": [{"command": unsafe_command}]})
                    )

    def test_requests_and_model_responses_are_bounded(self) -> None:
        with self.assertRaises(shell_ai.UserError):
            shell_ai.suggest("how", "x" * (shell_ai.MAX_REQUEST_CHARS + 1))

        oversized = subprocess.CompletedProcess(
            [], 0, "x" * (shell_ai.MAX_RESPONSE_CHARS + 1), ""
        )
        with mock.patch.dict(os.environ, {"SEELE_SHELL_AI_PI": "/fake/pi"}, clear=False):
            with mock.patch.object(shell_ai.subprocess, "run", return_value=oversized):
                with self.assertRaises(shell_ai.UserError):
                    shell_ai.invoke_pi("request")

    def test_local_classifier_overrides_an_unsafe_model_label(self) -> None:
        destructive = (
            "blkdiscard /dev/sdb",
            "cp image.raw /dev/sdb",
            "cryptsetup luksFormat /dev/sdb1",
            "rm -rf result",
            "find . -type f -delete",
            "nix profile wipe-history --older-than 30d",
            "mkfs.ext4 /dev/sdb1",
            "dd if=image of=/dev/nvme0n1",
            "nix-collect-garbage -d",
            "nix-env --delete-generations old",
            "nix store gc",
            "nh clean all",
            "git reset --hard HEAD",
            "jj abandon @",
        )
        for command in destructive:
            with self.subTest(command=command):
                self.assertTrue(shell_ai.is_destructive(command))

        for command in ("jj status", "nix flake show", "rg --files", "systemctl status sshd"):
            with self.subTest(command=command):
                self.assertFalse(shell_ai.is_destructive(command))

        parsed = shell_ai.parse_suggestions(
            '{"suggestions":[{"command":"rm old.log","description":"remove it","destructive":false}]}'
        )
        self.assertTrue(parsed[0]["destructive"])
        self.assertTrue(shell_ai.format_insertion(parsed[0]).startswith("# DESTRUCTIVE"))

    def test_failure_state_keeps_only_the_last_failure_in_private_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            environment = {"XDG_RUNTIME_DIR": temporary}
            with mock.patch.dict(os.environ, environment, clear=False):
                session = shell_ai.create_session()
                with mock.patch.dict(os.environ, {shell_ai.SESSION_ENV: str(session)}, clear=False):
                    shell_ai.begin_capture()
                    shell_ai.append_capture(session, b"\x1b[31mfirst failure\x1b[0m\n")
                    shell_ai.finish_capture("false", 1)
                    first = shell_ai.load_failure()
                    self.assertEqual(first, {"command": "false", "status": 1, "stderr": "first failure"})

                    shell_ai.begin_capture()
                    shell_ai.append_capture(session, b"successful noise\n")
                    shell_ai.finish_capture("true", 0)
                    self.assertEqual(shell_ai.load_failure(), first)

                    shell_ai.begin_capture()
                    shell_ai.append_capture(session, b"second failure\n")
                    shell_ai.finish_capture("broken --again", 23)
                    self.assertEqual(
                        shell_ai.load_failure(),
                        {"command": "broken --again", "status": 23, "stderr": "second failure"},
                    )
                    self.assertEqual(session.stat().st_mode & 0o077, 0)
                    self.assertEqual((session / "failure.json").stat().st_mode & 0o077, 0)

    def test_capture_wrapper_tees_stderr_records_failure_and_cleans_up(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            failure_copy = root / "failure.json"
            session_copy = root / "session"
            fake_fish = self.executable(
                root,
                "fish",
                """
                #!/bin/sh
                "$SEELE_TEST_PYTHON" "$SEELE_TEST_SOURCE" begin
                printf '\033[31mcaptured failure\033[0m\n' >&2
                "$SEELE_TEST_PYTHON" "$SEELE_TEST_SOURCE" finish --status 19 --command 'broken command'
                cp "$SEELE_SHELL_AI_SESSION/failure.json" "$SEELE_TEST_FAILURE_COPY"
                printf '%s' "$SEELE_SHELL_AI_SESSION" > "$SEELE_TEST_SESSION_COPY"
                """,
            )
            environment = os.environ.copy()
            environment.update(
                {
                    "XDG_RUNTIME_DIR": temporary,
                    "SEELE_TEST_PYTHON": sys.executable,
                    "SEELE_TEST_SOURCE": str(SOURCE),
                    "SEELE_TEST_FAILURE_COPY": str(failure_copy),
                    "SEELE_TEST_SESSION_COPY": str(session_copy),
                }
            )
            result = subprocess.run(
                [sys.executable, str(SOURCE), "capture", "--fish", str(fake_fish)],
                capture_output=True,
                env=environment,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
            self.assertIn(b"captured failure", result.stderr)
            self.assertEqual(
                json.loads(failure_copy.read_text()),
                {"command": "broken command", "status": 19, "stderr": "captured failure"},
            )
            self.assertFalse(Path(session_copy.read_text()).exists())

    def test_pi_is_ephemeral_toolless_and_isolated_from_project_instructions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            arguments_file = root / "arguments"
            fake_pi = self.executable(
                root,
                "pi",
                """
                #!/bin/sh
                printf '%s\n' "$@" > "$SEELE_TEST_ARGUMENTS"
                printf '%s\n' '{"suggestions":[{"command":"jj status","description":"Inspect state","destructive":false}]}'
                """,
            )
            with mock.patch.dict(
                os.environ,
                {"SEELE_SHELL_AI_PI": str(fake_pi), "SEELE_TEST_ARGUMENTS": str(arguments_file)},
                clear=False,
            ):
                response = shell_ai.invoke_pi("request")
            self.assertIn("jj status", response)
            arguments = arguments_file.read_text().splitlines()
            for required in (
                "--offline",
                "--no-session",
                "--no-tools",
                "--no-extensions",
                "--no-skills",
                "--no-prompt-templates",
                "--no-context-files",
                "--no-approve",
            ):
                self.assertIn(required, arguments)

    def test_multiple_interpretations_are_selected_explicitly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake_fzf = self.executable(root, "fzf", "#!/bin/sh\nsed -n '2p'\n")
            suggestions = [
                {"command": "one", "description": "first", "destructive": False},
                {"command": "two", "description": "second", "destructive": False},
            ]
            with mock.patch.dict(os.environ, {"SEELE_SHELL_AI_FZF": str(fake_fzf)}, clear=False):
                self.assertEqual(shell_ai.select_suggestion(suggestions)["command"], "two")

    def test_only_plain_interactive_fish_processes_are_wrapped(self) -> None:
        self.assertTrue(shell_ai.capture_eligible(["/nix/store/example/bin/fish"], True, True))
        self.assertTrue(shell_ai.capture_eligible(["-fish", "-il"], True, True))
        self.assertFalse(shell_ai.capture_eligible(["fish", "-ic", "echo test"], True, True))
        self.assertFalse(shell_ai.capture_eligible(["fish", "script.fish"], True, True))
        self.assertFalse(shell_ai.capture_eligible(["fish"], False, True))

    def test_fish_integration_uses_one_insertion_path_and_never_auto_executes(self) -> None:
        if FEATURE is None:
            self.skipTest("feature module path not provided")
        source = FEATURE.read_text()
        self.assertIn("__seele_ai_insert how", source)
        self.assertIn("__seele_ai_insert debug", source)
        self.assertIn('commandline --replace -- "$suggestion"', source)
        self.assertIn("commandline -f execute", source)
        self.assertNotIn("commandline -f execute\n              return", source)
        self.assertIn('onEvent = "fish_preexec";', source)
        self.assertIn('onEvent = "fish_postexec";', source)
        self.assertIn('onEvent = "fish_posterror";', source)
        self.assertEqual(source.count('return "$command_status"'), 2)


if __name__ == "__main__":
    unittest.main()
