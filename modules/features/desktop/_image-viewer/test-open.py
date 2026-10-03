"""Exercise the desktop adapter through Bash with an argv-recording imv."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("open.sh").resolve()


class ImageOpening(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="seele-images-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "arguments.json"
        binary = self.root / "imv"
        binary.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "with open(os.environ['ARGV_OUTPUT'], 'w') as output:\n"
            "    json.dump(sys.argv[1:], output)\n"
        )
        binary.chmod(0o700)
        self.env = dict(os.environ, PATH=str(self.root), ARGV_OUTPUT=str(self.output))

    def run_viewer(self, *args, success=True):
        result = subprocess.run(
            [shutil.which("bash"), "-euo", "pipefail", str(SCRIPT), *args],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
        )
        if not success:
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(self.output.exists())
            return
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.output.read_text())

    def test_single_file_starts_in_its_directory(self):
        # Both directory and filename end in newlines; shell punctuation is data.
        directory = self.root / "album ' $()\n"
        directory.mkdir()
        image = directory / "-selected; $(touch injected)\n"
        image.touch()
        self.assertEqual(
            self.run_viewer(str(image.relative_to(self.root))),
            ["-n", str(image), "--", str(directory)],
        )
        self.assertFalse((self.root / "injected").exists())

    def test_multiple_files_do_not_expand_to_folders(self):
        images = [self.root / "-first.png", self.root / "second\n.png"]
        for image in images:
            image.touch()
        self.assertEqual(
            self.run_viewer(images[0].name, str(images[1])),
            ["--", *(str(image) for image in images)],
        )

    def test_symlink_uses_the_visible_containing_folder(self):
        target = self.root / "elsewhere"
        target.mkdir()
        (target / "source.png").touch()
        link = self.root / "link.png"
        link.symlink_to(target / "source.png")
        self.assertEqual(
            self.run_viewer(link.name), ["-n", str(link), "--", str(self.root)]
        )

    def test_missing_file_and_directory_are_forwarded(self):
        for name in ("--help", "."):
            with self.subTest(name=name):
                self.assertEqual(self.run_viewer(name), ["--", f"{self.root}/{name}"])

    def test_no_files_preserves_empty_invocation(self):
        self.assertEqual(self.run_viewer(), ["--"])

    def test_empty_path_is_not_the_current_directory(self):
        self.run_viewer("", success=False)


if __name__ == "__main__":
    unittest.main()
