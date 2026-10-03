#!/usr/bin/env python3
"""Reload a private config through the real binding without sourcing a decoy."""
import fcntl
import os
from pathlib import Path
import pty
import shutil
import struct
import subprocess
import tempfile
import termios
import time

source = Path(__file__).resolve().parent.parent.joinpath("tmux.nix").read_text()
lines = [line.strip() for line in source.splitlines()
         if "set-option -gF @seele-config-file" in line or "bind-key r source-file" in line]
assert len(lines) == 2
binary = shutil.which(os.environ.get("TMUX_BIN", "tmux"))
assert binary
with tempfile.TemporaryDirectory(prefix="seele-tmux-reload-") as temp:
    root = Path(temp)
    decoy = root / ".config/tmux/tmux.conf"
    decoy.parent.mkdir(parents=True)
    decoy.write_text("set -g @foreign-config yes\n")
    config = root / "private [xdg], $; ' config.conf"
    included = root / "included.conf"
    included.write_text("set -g @included yes\n")
    prefix = "set -g prefix C-s\n" + "\n".join(lines) + '\nsource-file "' + str(included) + '"\n'
    config.write_text(prefix + "set -g @reload-marker before\n")
    socket = str(root / "socket")
    env = {**os.environ, "HOME": temp, "XDG_CONFIG_HOME": str(root / "private"), "TERM": "xterm-256color"}
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)

    def tmux(*args, check=True):
        return subprocess.run([binary, "-S", socket, *args], env=env, text=True,
                              capture_output=True, check=check).stdout.strip()

    def wait(check):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if check():
                return
            time.sleep(0.03)
        raise AssertionError("configuration did not reload")

    master, slave = pty.openpty()
    attached = None
    try:
        tmux("-f", str(config), "new-session", "-d", "sleep", "30")
        assert tmux("show", "-gv", "@seele-config-file") == str(config)
        assert tmux("show", "-gv", "@included") == "yes"
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
        attached = subprocess.Popen([binary, "-S", socket, "attach-session"], env=env,
                                    stdin=slave, stdout=slave, stderr=slave)
        wait(lambda: tmux("list-clients") != "")
        config.write_text(prefix + "set -g @reload-marker after\n")
        os.write(master, b"\x13r")
        wait(lambda: tmux("show", "-gv", "@reload-marker") == "after")
        assert tmux("show", "-gv", "@seele-config-file") == str(config)
        assert tmux("show", "-gv", "@foreign-config", check=False) == ""
        # Source failure must not fall back to the foreign configuration.
        config.unlink()
        os.write(master, b"\x13r")
        time.sleep(0.1)
        assert tmux("show", "-gv", "@foreign-config", check=False) == ""
        assert tmux("show", "-gv", "@reload-marker") == "after"
        print("tmux reload: real binding, exact path, includes, decoy and missing file passed")
    finally:
        subprocess.run([binary, "-S", socket, "kill-server"], env=env, capture_output=True)
        if attached:
            attached.wait(timeout=5)
        os.close(master)
        os.close(slave)
