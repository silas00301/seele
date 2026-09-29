"""Test real Television preview/edit templates with literal file selections."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import struct
import sys
import tempfile
import time

binary = shutil.which(sys.argv[1]) or str(Path(sys.argv[1]).resolve())
template = Path(sys.argv[2]).read_text().removesuffix("\n")
names = ["space name", "apostrophe's", r"back\\slash", "--cmd", "$(touch INJECTED)", "semi;colon", '`touch INJECTED`', 'double"quote', "€unicode"]

def run_case(names):
    with tempfile.TemporaryDirectory(prefix="seele-tv-files-") as directory:
        root = Path(directory)
        (root / "cable").mkdir()
        recorder = root / "recorder"
        recorder.write_text(
            f"#!{sys.executable}\n"
            "import json, sys\nfrom pathlib import Path\n"
            f"root = Path({str(root)!r})\n"
            "if sys.argv[1] == 'source':\n"
            f"    print({chr(10).join(names)!r})\n"
            "else:\n"
            "    (root / sys.argv[1]).write_text(json.dumps(sys.argv[2:]))\n"
        )
        recorder.chmod(0o700)
        config = root / "config.toml"
        config.write_text("")
        # Same template and shell used by both file-channel command sites.
        (root / "cable" / "fixture.toml").write_text(
            '[metadata]\nname="fixture"\n[source]\n'
            + 'command=' + json.dumps(f"{recorder} source") + '\nno_sort=true\n'
            + '[preview]\ncommand=' + json.dumps(f"{recorder} preview -- {template}") + '\nshell="bash"\n'
            + '[keybindings]\nctrl-e="actions:edit"\ntab="toggle_selection_down"\n'
            + '[actions.edit]\ncommand=' + json.dumps(f"{recorder} edit -- {template}")
            + '\nshell="bash"\nseparator="\\n"\nmode="execute"\n'
        )
        env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory + "/config", XDG_DATA_HOME=directory + "/data", TERM="xterm-256color", SHELL=shutil.which("bash"))
        pid, terminal = pty.fork()
        if pid == 0:
            os.chdir(directory)
            os.execve(binary, [binary, "fixture", "--config-file", str(config), "--cable-dir", str(root / "cable")], env)
        fcntl.ioctl(terminal, 0x5414, struct.pack("HHHH", 30, 100, 0, 0))
        output = bytearray()
        deadline = time.monotonic() + 15
        sent = False
        exited = False
        try:
            while time.monotonic() < deadline:
                if select.select([terminal], [], [], 0.05)[0]:
                    try:
                        output.extend(os.read(terminal, 65536))
                    except OSError:
                        break
                if not sent and (root / "preview").exists():
                    preview = json.loads((root / "preview").read_text())
                    assert preview[0] == "--" and preview[1:] == [names[0]], preview
                    # Mark each row, then trigger the configured edit action.
                    os.write(terminal, b"\t" * len(names) + b"\x05")
                    sent = True
                if (root / "edit").exists():
                    break
            assert (root / "edit").exists(), output[-3000:].decode(errors="replace")
            arguments = json.loads((root / "edit").read_text())
            assert arguments[0] == "--", arguments
            assert sorted(arguments[1:]) == sorted(names), arguments
            assert not (root / "INJECTED").exists()
            _, status = os.waitpid(pid, 0)
            exited = True
            assert os.waitstatus_to_exitcode(status) == 0, status
        finally:
            if not exited:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(terminal)

for selection in [names] + [[name] for name in names]:
    run_case(selection)
print("PASS: Television preview and multi-select edit preserve literal filenames")
