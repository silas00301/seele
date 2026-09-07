"""Exercise real ripgrep records and argument boundaries for project search."""

import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).with_name("text.py")
spec = importlib.util.spec_from_file_location("project_text", HELPER)
text = importlib.util.module_from_spec(spec)
spec.loader.exec_module(text)


class ProjectTextTests(unittest.TestCase):
    def test_paths_round_trip_without_shell_or_field_interpretation(self):
        for path in [b"plain.txt", b"a:b c'd;$(touch BAD).md", b"tab\tnewline\n.txt", b"-option.txt", b"bad-\xff.txt"]:
            with self.subTest(path=path):
                event = {"type": "match", "data": {
                    "path": {"bytes": base64.b64encode(path).decode()},
                    "line_number": 42,
                    "lines": {"text": "hello\tworld\x1b[31m\n"},
                }}
                row = text.entry(event)
                token, line, label = row.split("\t")
                self.assertEqual(text.location(token, line), (os.fsdecode(path), "42"))
                self.assertNotIn("\n", row)
                self.assertNotIn("\x1b", label)
                self.assertRegex(token, r"^[A-Za-z0-9_=-]+$")

    def test_invalid_locations_are_rejected(self):
        token = base64.urlsafe_b64encode(b"file.txt").decode()
        for args in [("';echo BAD", "1"), (token, "0"), (token, "1;echo BAD"), ("AA==", "1")]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                text.location(*args)

    def test_real_search_respects_hidden_and_ignored_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".git").mkdir()
            (root / ".gitignore").write_text("ignored.txt\n")
            (root / "ignored.txt").write_text("ignored\n")
            (root / ".hidden").write_text("hidden\n")
            (root / ".jj").mkdir()
            (root / ".jj" / "state").write_text("private metadata\n")
            name = "a:b '$(touch BAD)\t\n.txt"
            (root / name).write_text("first\nneedle\n")
            for hidden in [False, True]:
                result = subprocess.run(
                    [sys.executable, str(HELPER), "source"] + (["--hidden"] if hidden else []),
                    cwd=root, capture_output=True, text=True, check=True,
                )
                rows = [row.split("\t") for row in result.stdout.splitlines()]
                paths = [text.location(row[0], row[1])[0] for row in rows]
                self.assertIn("./" + name, paths)
                self.assertNotIn("./ignored.txt", paths)
                self.assertNotIn("./.jj/state", paths)
                self.assertEqual("./.hidden" in paths, hidden)
                self.assertFalse((root / "BAD").exists())

    def test_preview_and_editor_preserve_argument_boundaries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "args.json"
            stub = f"#!{sys.executable}\nimport json,os,sys\nopen(os.environ['ARGS_FILE'],'w').write(json.dumps(sys.argv[1:]))\n"
            for command in ["bat", "nvim"]:
                path = root / command
                path.write_text(stub)
                path.chmod(0o755)
            filename = "-a:b '$(touch BAD)\t\n.txt"
            token = base64.urlsafe_b64encode(os.fsencode(filename)).decode()
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"], ARGS_FILE=str(output))
            for action in ["preview", "edit"]:
                subprocess.run([sys.executable, str(HELPER), action, token, "42"], env=env, cwd=root, check=True)
                args = json.loads(output.read_text())
                self.assertEqual(args[-2:], ["--", filename])
                self.assertIn("42" if action == "preview" else "+42", args)
                self.assertFalse((root / "BAD").exists())

    def test_empty_search_succeeds(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "empty").write_text("")
            result = subprocess.run([sys.executable, str(HELPER), "source"], cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
