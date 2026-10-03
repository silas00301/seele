"""Exercise the exact Fish body with a recording curl, without network access."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source, fish = Path(sys.argv[1]).resolve(), sys.argv[2]
with tempfile.TemporaryDirectory(prefix="seele-gitignore-") as directory:
    root = Path(directory)
    curl = root / "curl"
    curl.write_text(
        f"#!{sys.executable}\n"
        "import json, os, sys\n"
        "from pathlib import Path\n"
        "Path(os.environ['RECORD']).write_text(json.dumps(sys.argv[1:]))\n"
        "status = int(os.environ.get('CURL_STATUS', '0'))\n"
        "if status: print('synthetic HTTP failure', file=sys.stderr)\n"
        "else: print('# requested templates')\n"
        "sys.exit(status)\n"
    )
    curl.chmod(0o700)
    function = root / "function.fish"
    function.write_text("function gitignore\n" + source.read_text().replace("@curl@", str(curl)) + "\nend\ngitignore $argv\n")
    record = root / "record.json"
    env = dict(os.environ, HOME=str(root), RECORD=str(record))

    def run(arguments, status=0):
        record.unlink(missing_ok=True)
        return subprocess.run(
            [fish, "--no-config", str(function), *arguments],
            env=dict(env, CURL_STATUS=str(status)), capture_output=True, text=True,
        )

    for names, suffix in [(["python"], "python"), (["python", "linux"], "python,linux"), (["c++,vim", "macos"], "c++,vim,macos")]:
        result = run(names)
        assert result.returncode == 0, result.stderr
        assert result.stdout == "# requested templates\n"
        args = json.loads(record.read_text())
        assert args == ["--fail", "--silent", "--show-error", "--location", "--connect-timeout", "10", "--max-time", "30", "--proto", "=https", "--proto-redir", "=https", "--url", "https://www.toptal.com/developers/gitignore/api/" + suffix]

    for invalid in [[], [""], ["--output", "file"], ["python linux"], ["../python"], ["python?x=y"], ["python,,linux"], ["python\nlinux"]]:
        result = run(invalid)
        assert result.returncode == 2, (invalid, result)
        assert not result.stdout
        assert not record.exists(), invalid
    for flag in ["--help", "-h"]:
        result = run([flag])
        assert result.returncode == 0 and "Usage:" in result.stdout
        assert not record.exists()
    result = run(["python"], 22)
    assert result.returncode == 22 and not result.stdout
    assert "HTTP failure" in result.stderr
print("PASS: template joining, invalid names, help, curl policy and failure propagation")
