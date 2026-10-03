"""Exercise the copy transaction without a desktop or real clipboard."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]).resolve()
bash = shutil.which("bash")
assert bash
with tempfile.TemporaryDirectory(prefix="imv-copy-test-") as directory:
    root = Path(directory)
    binaries = root / "bin"
    binaries.mkdir()
    temporary = root / "temporary"
    temporary.mkdir()
    clipboard = root / "clipboard"
    converter = binaries / "magick"
    converter.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, stat, sys
assert sys.argv[1] == "-[0]"
assert len(sys.argv) == 3 and sys.argv[2].startswith("PNG:")
out = pathlib.Path(sys.argv[2][4:])
assert stat.S_IMODE(out.parent.stat().st_mode) == 0o700
assert sys.stdin.buffer.read() == b"original image bytes"
mode = os.environ.get("CONVERT_MODE", "ok")
out.write_bytes(b"" if mode == "empty" else b"converted PNG bytes")
assert stat.S_IMODE(out.stat().st_mode) == 0o600
sys.exit(7 if mode == "fail" else 0)
''')
    copier = binaries / "wl-copy"
    copier.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, sys
assert sys.argv[1:] == ["--type", "image/png"]
data = sys.stdin.buffer.read()
assert data == b"converted PNG bytes"
if os.environ.get("COPY_FAIL"): sys.exit(9)
pathlib.Path(os.environ["TEST_CLIPBOARD"]).write_bytes(data)
''')
    for binary in (converter, copier):
        binary.chmod(0o755)
    env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ["PATH"],
               TMPDIR=str(temporary), TEST_CLIPBOARD=str(clipboard))

    def run(name, expected, **overrides):
        clipboard.write_bytes(b"previous clipboard")
        result = subprocess.run([bash, "-euo", "pipefail", str(script)], cwd=root,
                                env=dict(env, imv_current_file=name, **overrides),
                                capture_output=True)
        assert result.returncode == expected, (result.returncode, result.stderr)
        assert clipboard.read_bytes() == (b"converted PNG bytes" if expected == 0 else b"previous clipboard")
        assert list(temporary.iterdir()) == [], "temporary conversion survived"

    for name in ["image.png", "spaces and 'quotes'.jpg", "-option[2]:name.gif", "日本語\nimage.webp"]:
        source = root / name
        source.write_bytes(b"original image bytes")
        run(name, 0)
        assert source.read_bytes() == b"original image bytes"
    run("missing.png", 1)
    run("", 1)
    run("image.png", 7, CONVERT_MODE="fail")
    run("image.png", 1, CONVERT_MODE="empty")
    run("image.png", 9, COPY_FAIL="1")
print("imv copies complete images, preserves literal paths and clipboard on failure, and cleans up")
