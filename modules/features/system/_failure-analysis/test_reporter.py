#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import io
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock


def load_module(name: str, path: str):
    specification = importlib.util.spec_from_file_location(name, path)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


REPORTER_PATH = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).with_name("reporter.py"))
GENERATOR_PATH = sys.argv[2] if len(sys.argv) > 2 else str(Path(__file__).with_name("generator.py"))
reporter = load_module("seele_failure_reporter", REPORTER_PATH)
generator = load_module("seele_failure_generator", GENERATOR_PATH)


def completed(arguments, returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(arguments, returncode, stdout, stderr)


class CollectionTests(unittest.TestCase):
    def test_unit_context_is_limited_to_failed_invocation(self):
        invocation = "0123456789abcdef0123456789abcdef"
        derivation = "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-demo.drv"
        calls = []

        def fake_run(arguments, **_kwargs):
            calls.append(list(arguments))
            if "show" in arguments:
                return completed(
                    arguments,
                    stdout=(
                        "Id=demo.service\nDescription=Demo\nActiveState=failed\nSubState=failed\n"
                        f"Result=exit-code\nExecMainStatus=7\nInvocationID={invocation}\n"
                    ),
                )
            if arguments[0] == "/fake/nix":
                return completed(arguments, stdout="builder failed at the final step\n")
            if any(argument.startswith("_SYSTEMD_INVOCATION_ID=") for argument in arguments):
                rows = [
                    {
                        "__REALTIME_TIMESTAMP": "2000000",
                        "SYSLOG_IDENTIFIER": "demo",
                        "_PID": "10",
                        "MESSAGE": f"building {derivation}",
                    },
                    {
                        "__REALTIME_TIMESTAMP": "4000000",
                        "SYSLOG_IDENTIFIER": "demo",
                        "_PID": "10",
                        "MESSAGE": "GPU device reset while starting",
                    },
                ]
                return completed(arguments, stdout="\n".join(map(__import__("json").dumps, rows)))
            if "--dmesg" in arguments:
                return completed(
                    arguments,
                    stdout=__import__("json").dumps(
                        {
                            "__REALTIME_TIMESTAMP": "3000000",
                            "SYSLOG_IDENTIFIER": "kernel",
                            "MESSAGE": "GPU reset reported by driver",
                        }
                    ),
                )
            raise AssertionError(f"unexpected command: {arguments}")

        with mock.patch.dict(os.environ, {"SEELE_FAILURE_NIX": "/fake/nix"}, clear=False):
            with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
                report, summary = reporter.collect_unit("demo.service")

        invocation_calls = [call for call in calls if any("_SYSTEMD_INVOCATION_ID=" in item for item in call)]
        self.assertIn(f"_SYSTEMD_INVOCATION_ID={invocation}", invocation_calls[0])
        self.assertIn("+", invocation_calls[0])
        self.assertIn(f"INVOCATION_ID={invocation}", invocation_calls[0])
        nix_call = next(call for call in calls if call[0] == "/fake/nix")
        self.assertEqual(nix_call, ["/fake/nix", "--offline", "log", derivation])
        kernel_call = next(call for call in calls if "--dmesg" in call)
        self.assertIn("--since=@1", kernel_call)
        self.assertIn("--until=@5", kernel_call)
        self.assertIn("builder failed at the final step", report)
        self.assertIn("GPU reset reported by driver", report)
        self.assertIn("exit 7", summary)

    def test_missing_invocation_does_not_fall_back_to_unbounded_journal(self):
        calls = []

        def fake_run(arguments, **_kwargs):
            calls.append(list(arguments))
            return completed(arguments, stdout="Id=demo.service\nResult=exit-code\nInvocationID=\n")

        with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
            report, _summary = reporter.collect_unit("demo.service")

        self.assertEqual(len(calls), 1)
        self.assertIn("No journal entries were available for this invocation", report)

    def test_on_failure_metadata_wins_a_restart_race(self):
        failed_invocation = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        restarted_invocation = "cccccccccccccccccccccccccccccccc"
        calls = []

        def fake_run(arguments, **_kwargs):
            calls.append(list(arguments))
            if "show" in arguments:
                return completed(
                    arguments,
                    stdout=f"Id=demo.service\nResult=success\nExecMainStatus=0\nInvocationID={restarted_invocation}\n",
                )
            return completed(arguments)

        environment = {
            "MONITOR_UNIT": "demo.service",
            "MONITOR_INVOCATION_ID": failed_invocation,
            "MONITOR_SERVICE_RESULT": "exit-code",
            "MONITOR_EXIT_CODE": "exited",
            "MONITOR_EXIT_STATUS": "23",
        }
        with mock.patch.dict(os.environ, environment, clear=False):
            with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
                report, summary = reporter.collect_unit("demo.service")

        journal_call = next(call for call in calls if any("_SYSTEMD_INVOCATION_ID=" in item for item in call))
        self.assertIn(f"_SYSTEMD_INVOCATION_ID={failed_invocation}", journal_call)
        self.assertIn(f"InvocationID={failed_invocation}", report)
        self.assertIn("exit 23", summary)

    def test_only_handler_is_excluded_from_reporting(self):
        with mock.patch.object(reporter, "run_capture", return_value=completed([], stdout="InvocationID=\n")):
            report, _summary = reporter.collect_unit("seele-failure-test.service")
        self.assertIn("Failed unit: seele-failure-test.service", report)

        with self.assertRaises(ValueError):
            reporter.collect_unit("seele-failure-report@demo.service.service")


class PrivacyTests(unittest.TestCase):
    def test_no_action_is_local_only_and_report_is_private(self):
        with tempfile.TemporaryDirectory() as temporary:
            os.chmod(temporary, 0o700)
            with mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": temporary}, clear=False):
                with mock.patch.object(reporter, "known_secret_values", return_value=set()):
                    with mock.patch.object(reporter, "notify", return_value=None):
                        with mock.patch.object(reporter, "analyze_report") as analyze:
                            self.assertEqual(reporter.store_offer("raw report", "demo.service", "failed"), 0)
            reports = list((Path(temporary) / "seele-shell" / "failures").glob("*.txt"))
            self.assertEqual(len(reports), 1)
            self.assertEqual(stat.S_IMODE(reports[0].stat().st_mode), 0o600)
            self.assertEqual(reports[0].read_text(encoding="utf-8"), "raw report")
            analyze.assert_not_called()

    def test_see_error_never_invokes_ai(self):
        with tempfile.TemporaryDirectory() as temporary:
            os.chmod(temporary, 0o700)
            with mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": temporary}, clear=False):
                with mock.patch.object(reporter, "known_secret_values", return_value=set()):
                    with mock.patch.object(reporter, "notify", return_value="view"):
                        with mock.patch.object(reporter, "launch_view", return_value=True) as view:
                            with mock.patch.object(reporter, "analyze_report") as analyze:
                                reporter.store_offer("raw report", "demo.service", "failed")
            view.assert_called_once()
            analyze.assert_not_called()

    def test_local_view_uses_only_transient_ghostty_and_neovim(self):
        captured = {}

        def fake_run(arguments, **_kwargs):
            captured["arguments"] = list(arguments)
            return completed(arguments)

        environment = {
            "SEELE_FAILURE_SYSTEMD_RUN": "/tools/systemd-run",
            "SEELE_FAILURE_GHOSTTY": "/tools/ghostty",
            "SEELE_FAILURE_NVIM": "/tools/nvim",
            "SEELE_FAILURE_VIEW_LUA": "/tools/view.lua",
            "SEELE_FAILURE_PI": "/tools/pi",
        }
        with mock.patch.dict(os.environ, environment, clear=False):
            with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
                with mock.patch.object(reporter.secrets, "token_hex", return_value="abcdef"):
                    self.assertTrue(reporter.launch_view(Path("/run/user/1000/report.txt"), "a" * 16))

        arguments = captured["arguments"]
        self.assertEqual(arguments[0], "/tools/systemd-run")
        self.assertIn("--service-type=exec", arguments)
        self.assertIn("/tools/ghostty", arguments)
        self.assertIn("/tools/nvim", arguments)
        self.assertNotIn("/tools/pi", arguments)

    def test_ai_receives_only_stdin_redaction_and_no_tools(self):
        invocation = {}

        def fake_run(arguments, **kwargs):
            invocation["arguments"] = list(arguments)
            invocation["stdin"] = kwargs.get("input_text")
            invocation["cwd"] = kwargs.get("cwd")
            invocation["cwd_mode"] = stat.S_IMODE(kwargs["cwd"].stat().st_mode)
            return completed(arguments, stdout="Likely cause: invalid configuration\nCheck the unit setting.\n")

        report = (
            "TOKEN=known-secret\nAuthorization: Bearer opaque-value\n"
            "remote=https://alice:password@example.test/repo\n"
            "github=ghp_abcdefghijklmnopqrstuvwxyz123456\n"
            '"api_token": "json-secret"\n'
            "ExecStart=demo --password cli-secret\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            os.chmod(temporary, 0o700)
            with mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": temporary}, clear=False):
                with mock.patch.object(reporter, "known_secret_values", return_value={"known-secret"}):
                    with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
                        analysis, error = reporter.analyze_report(report)

        self.assertIsNone(error)
        self.assertIn("Likely cause", analysis)
        self.assertNotIn("known-secret", invocation["stdin"])
        self.assertNotIn("opaque-value", invocation["stdin"])
        self.assertNotIn("alice:password", invocation["stdin"])
        self.assertNotIn("ghp_abcdefghijklmnopqrstuvwxyz123456", invocation["stdin"])
        self.assertNotIn("json-secret", invocation["stdin"])
        self.assertNotIn("cli-secret", invocation["stdin"])
        self.assertIn("--no-tools", invocation["arguments"])
        self.assertIn("--no-extensions", invocation["arguments"])
        self.assertIn("--no-context-files", invocation["arguments"])
        self.assertEqual(invocation["cwd"].name, "failure-analysis")
        self.assertEqual(invocation["cwd_mode"], 0o700)
        self.assertTrue(all(report not in argument for argument in invocation["arguments"]))

    def test_analyze_action_appends_result_after_opt_in(self):
        with tempfile.TemporaryDirectory() as temporary:
            os.chmod(temporary, 0o700)
            notifications = iter(("analyze", None))
            with mock.patch.dict(os.environ, {"XDG_RUNTIME_DIR": temporary}, clear=False):
                with mock.patch.object(reporter, "known_secret_values", return_value=set()):
                    with mock.patch.object(reporter, "notify", side_effect=lambda *_args, **_kwargs: next(notifications)):
                        with mock.patch.object(reporter, "analyze_report", return_value=("Likely cause: bad option", None)) as analyze:
                            reporter.store_offer("raw report", "demo.service", "failed")
            saved = next((Path(temporary) / "seele-shell" / "failures").glob("*.txt")).read_text(encoding="utf-8")
            self.assertIn("raw report", saved)
            self.assertIn("AI analysis (explicitly requested)", saved)
            self.assertIn("Likely cause: bad option", saved)
            analyze.assert_called_once_with("raw report")

    def test_root_handoff_uses_clean_environment_and_stdin(self):
        fake_user = types.SimpleNamespace(pw_uid=1000, pw_name="silash", pw_dir="/home/silash")
        captured = {}

        def fake_run(arguments, **kwargs):
            captured["arguments"] = list(arguments)
            captured["stdin"] = kwargs.get("input_text")
            return completed(arguments)

        with mock.patch.object(reporter.pwd, "getpwnam", return_value=fake_user):
            with mock.patch.object(
                reporter,
                "user_session_environment",
                return_value={"HOME": "/home/silash", "XDG_RUNTIME_DIR": "/run/user/1000"},
            ):
                with mock.patch.object(reporter, "run_capture", side_effect=fake_run):
                    reporter.offer_as_user("silash", "private report", "demo.service", "failed")

        self.assertIn("-i", captured["arguments"])
        self.assertIn("store-envelope", captured["arguments"])
        self.assertNotIn("private report", captured["arguments"])
        self.assertNotIn("demo.service", captured["arguments"])
        envelope = __import__("json").loads(captured["stdin"])
        self.assertEqual(envelope, {"report": "private report", "subject": "demo.service", "summary": "failed"})


class RebuildTests(unittest.TestCase):
    class FakeProcess:
        def __init__(self, output: str, returncode: int):
            self.stdout = io.BytesIO(output.encode("utf-8"))
            self.returncode = returncode

        def wait(self):
            return self.returncode

    def test_failed_rebuild_enters_same_consent_path(self):
        process = self.FakeProcess("evaluating\nbuild failed\n", 4)
        with mock.patch.object(reporter.subprocess, "Popen", return_value=process) as popen:
            with mock.patch.object(reporter, "store_offer", return_value=0) as offer:
                with mock.patch.object(sys, "stdout", io.TextIOWrapper(io.BytesIO())):
                    result = reporter.rebuild(["os", "switch", "--dry"])
        self.assertEqual(result, 4)
        self.assertEqual(popen.call_args.args[0][1:], ["os", "switch", "--dry"])
        self.assertIn("build failed", offer.call_args.args[0])
        self.assertEqual(offer.call_args.args[1], "NixOS rebuild")

    def test_successful_rebuild_does_not_offer_report(self):
        process = self.FakeProcess("done\n", 0)
        with mock.patch.object(reporter.subprocess, "Popen", return_value=process):
            with mock.patch.object(reporter, "store_offer") as offer:
                with mock.patch.object(sys, "stdout", io.TextIOWrapper(io.BytesIO())):
                    self.assertEqual(reporter.rebuild([]), 0)
        offer.assert_not_called()


    def test_progress_bytes_are_not_translated_or_line_buffered(self):
        frames = "\r\x1b[2Kbuilding 1/2\r\x1b[2Kbuilding 2/2 ✓\r\n"
        process = self.FakeProcess(frames, 0)
        sink = io.BytesIO()
        stdout = io.TextIOWrapper(sink)
        with mock.patch.object(reporter.subprocess, "Popen", return_value=process) as popen:
            with mock.patch.object(sys, "stdout", stdout):
                self.assertEqual(reporter.rebuild([]), 0)
        self.assertEqual(sink.getvalue(), frames.encode("utf-8"))
        self.assertFalse(popen.call_args.kwargs.get("text", False))

    def test_unterminated_failure_output_has_a_bounded_tail(self):
        process = self.FakeProcess("x" * (reporter.MAX_COMMAND_OUTPUT * 3) + " final failure", 1)
        with mock.patch.object(reporter.subprocess, "Popen", return_value=process):
            with mock.patch.object(reporter, "store_offer") as offer:
                with mock.patch.object(sys, "stdout", io.TextIOWrapper(io.BytesIO())):
                    self.assertEqual(reporter.rebuild([]), 1)
        self.assertIn("final failure", offer.call_args.args[0])
        self.assertLess(len(offer.call_args.args[0]), reporter.MAX_COMMAND_OUTPUT + 1000)


class GeneratorTests(unittest.TestCase):
    def test_generator_respects_precedence_masks_and_excludes_itself(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            high = root / "high"
            low = root / "low"
            output = root / "output"
            high.mkdir()
            low.mkdir()
            output.mkdir()
            (high / "alpha.service").write_text("[Service]\nExecStart=true\n", encoding="utf-8")
            (low / "alpha.service").write_text("lower priority", encoding="utf-8")
            (low / "beta.service").write_text("[Service]\nExecStart=true\n", encoding="utf-8")
            (low / "seele-failure-report@.service").write_text("handler", encoding="utf-8")
            os.symlink("/dev/null", high / "masked.service")
            (low / "masked.service").write_text("lower priority", encoding="utf-8")
            with mock.patch.dict(os.environ, {"SEELE_FAILURE_UNIT_PATH": f"{high}:{low}"}, clear=False):
                generator.write_drop_ins(output)

            generated = sorted(path.parent.name for path in output.glob("*.service.d/*.conf"))
            self.assertEqual(generated, ["alpha.service.d", "beta.service.d"])
            drop_in = output / "alpha.service.d" / "50-seele-failure-report.conf"
            self.assertEqual(drop_in.read_text(encoding="utf-8"), generator.DROP_IN)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
