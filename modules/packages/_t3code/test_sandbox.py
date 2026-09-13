"""Exercise the patched, pinned AppRun using only a synthetic Electron process."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

launcher = Path(sys.argv[1]).resolve()
bash = Path(sys.argv[2]).resolve()
with tempfile.TemporaryDirectory(prefix="seele-t3-launcher-") as directory:
    root = Path(directory)
    app = root / "application with spaces"
    app.mkdir()
    (app / "AppRun").write_bytes(launcher.read_bytes())
    executable = app / "t3code"
    executable.write_text(
        f"#!{sys.executable}\n"
        "import json, os, pathlib, sys\n"
        "pathlib.Path(os.environ['FIXTURE_OUTPUT']).write_text(json.dumps({"
        "'args':sys.argv[1:], 'environment':{key:os.environ.get(key) for key in "
        "['HOME','PATH','XDG_DATA_DIRS','LD_LIBRARY_PATH','GSETTINGS_SCHEMA_DIR']}}))\n"
    )
    executable.chmod(0o700)
    # This reproduces the upstream automatic fallback trigger without invoking
    # any host namespace command. A secure launcher must never call this probe.
    probe = app / "unshare"
    probe.write_text(
        f"#!{sys.executable}\n"
        "import os, pathlib, sys\n"
        "pathlib.Path(os.environ['FIXTURE_PROBE']).touch()\n"
        "sys.exit(1)\n"
    )
    probe.chmod(0o700)
    home = root / "empty-home"
    home.mkdir(mode=0o700)
    output = root / "output.json"
    probed = root / "probe-called"
    environment = {
        "APPDIR": str(app),
        "HOME": str(home),
        "PATH": str(root / "empty-path"),
        "XDG_DATA_DIRS": "/fixture/data",
        "LD_LIBRARY_PATH": "/fixture/lib",
        "GSETTINGS_SCHEMA_DIR": "/fixture/schemas",
        "FIXTURE_OUTPUT": str(output),
        "FIXTURE_PROBE": str(probed),
    }
    for arguments in [[], ["t3code://open?directory=a%20b", "space and $dollar", "--ozone-platform=wayland"]]:
        subprocess.run(
            [str(bash), str(app / "AppRun"), *arguments],
            env=environment, cwd=home, check=True, timeout=5,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        result = json.loads(output.read_text())
        assert result["args"] == ["--disable-setuid-sandbox", *arguments], result
        assert not probed.exists(), "AppRun tried its unsafe sandbox fallback"
        values = result["environment"]
        assert values["HOME"] == str(home)
        assert values["PATH"] == f"{app}:{app}/usr/sbin:{environment['PATH']}"
        assert values["LD_LIBRARY_PATH"] == f"{app}/usr/lib:/fixture/lib"
        assert values["XDG_DATA_DIRS"] == f"{app}/usr/share/:/fixture/data:/usr/share/gnome:/usr/local/share/:/usr/share/"
        assert values["GSETTINGS_SCHEMA_DIR"] == f"{app}/usr/share/glib-2.0/schemas:/fixture/schemas"
print("T3 AppRun: sandbox flags, failed-probe isolation, URI/argv and environment forwarding passed")
