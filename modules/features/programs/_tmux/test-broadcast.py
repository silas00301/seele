#!/usr/bin/env python3
"""Exercise real tmux broadcast keys and status on a private attached server."""
import fcntl
import os
from pathlib import Path
import pty
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

config = Path(__file__).resolve().parent.parent.joinpath("tmux.nix").read_text()
binding = next(line.strip() for line in config.splitlines() if " S set-window-option synchronize-panes" in line)
status = re.search(r'        set -g status-left "(.*?)"', config)[1]
tmux_bin = shutil.which(os.environ.get("TMUX_BIN", "tmux"))
assert tmux_bin

with tempfile.TemporaryDirectory(prefix="seele-broadcast-") as temp:
    socket = str(Path(temp) / "tmux")
    env = {**os.environ, "HOME": temp, "TERM": "xterm-256color"}
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)

    def tmux(*args):
        return subprocess.run([tmux_bin, "-S", socket, *args], env=env, text=True,
                              capture_output=True, check=True).stdout.strip()

    def wait(check):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if check():
                return
            time.sleep(0.03)
        raise AssertionError("tmux state did not reach expected value")

    conf = Path(temp) / "tmux.conf"
    conf.write_text('set -g prefix C-s\nset -g status-left-length 20\n' + binding + '\nset -g status-left "' + status + '"\n')
    command = [sys.executable, "-u", "-c", "import sys; print('READY'); [print('INPUT:'+line.rstrip()) for line in sys.stdin]"]
    master, slave = pty.openpty()
    attached = None
    try:
        first = tmux("-f", str(conf), "new-session", "-d", "-P", "-F", "#{pane_id}", "-x", "100", "-y", "30", *command)
        second = tmux("split-window", "-h", "-P", "-F", "#{pane_id}", *command)
        other = tmux("new-window", "-d", "-P", "-F", "#{pane_id}", *command)
        tmux("select-pane", "-t", first)
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
        attached = subprocess.Popen([tmux_bin, "-S", socket, "attach-session"], env=env,
                                    stdin=slave, stdout=slave, stderr=slave)
        wait(lambda: tmux("list-clients") != "")

        def label(pane):
            return tmux("display-message", "-p", "-t", pane, "#{E:status-left}")

        def enabled(pane):
            return tmux("show-window-options", "-v", "-t", pane, "synchronize-panes") == "on"

        def captured(pane):
            return tmux("capture-pane", "-p", "-t", pane)

        wait(lambda: all("READY" in captured(p) for p in [first, second, other]))
        assert not enabled(first) and not enabled(other)
        assert "BROADCAST" not in label(first)
        os.write(master, b"\x13S")
        wait(lambda: enabled(first))
        assert "BROADCAST" in label(first) and not enabled(other)
        os.write(master, b"shared-input\r")
        wait(lambda: all("INPUT:shared-input" in captured(p) for p in [first, second]))
        assert "shared-input" not in captured(other)
        tmux("select-window", "-t", other)
        assert "BROADCAST" not in label(other) and enabled(first)
        tmux("select-window", "-t", first)
        assert "BROADCAST" in label(first)
        os.write(master, b"\x13S")
        wait(lambda: not enabled(first))
        assert "BROADCAST" not in label(first)
        os.write(master, b"local-input\r")
        wait(lambda: "INPUT:local-input" in captured(first))
        assert "local-input" not in captured(second) and not enabled(other)
        print("tmux broadcasting: real key toggle, delivery, isolation and status passed")
    finally:
        subprocess.run([tmux_bin, "-S", socket, "kill-server"], env=env, capture_output=True)
        if attached:
            attached.wait(timeout=5)
        os.close(master)
        os.close(slave)
