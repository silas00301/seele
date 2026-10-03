#!/usr/bin/env python3
"""Exercise the actual pane-move keys on a private tmux server and PTY."""
import fcntl
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

TMUX = shutil.which(os.environ.get("TMUX_BIN", "tmux"))
assert TMUX, "tmux is required"


def wait_for(check, description):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.02)
    raise AssertionError(description)


with tempfile.TemporaryDirectory(prefix="tmux-pane-move-") as temporary:
    root = Path(temporary)
    socket = root / "socket"
    env = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root / "config"), TERM="xterm-256color")
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)

    def tmux(*args):
        return subprocess.run([TMUX, "-S", str(socket), *args], env=env,
                              capture_output=True, text=True, check=True, timeout=5).stdout.strip()

    def field(pane, name):
        return tmux("display-message", "-p", "-t", pane, "#{" + name + "}")

    def snapshot():
        return tmux("list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}:#{window_id}:#{pane_left}:#{pane_top}")

    def activate(pane):
        tmux("switch-client", "-c", client, "-t", field(pane, "session_id"))
        tmux("select-window", "-t", pane)
        tmux("select-pane", "-t", pane)

    def press(key):
        os.write(master, b"\x13" + key.encode())

    def screen_contains(text):
        while select.select([master], [], [], 0)[0]:
            screen.extend(os.read(master, 65536))
        return text.encode() in screen

    config = root / "tmux.conf"
    config.write_text("set -g prefix C-s\nset -g status-right ''\nset -g default-shell " + shutil.which("bash") + "\n"
                      + Path(__file__).with_name("pane-move.conf").read_text())
    command = [sys.executable, "-c", "import time; time.sleep(120)"]
    master = slave = attached = None
    try:
        source = tmux("-f", str(config), "new-session", "-d", "-s", "source", "-P", "-F", "#{pane_id}",
                      "-x", "120", "-y", "40", *command)
        target = tmux("new-window", "-d", "-P", "-F", "#{pane_id}", *command)
        original_pid = field(source, "pane_pid")
        target_pid = field(target, "pane_pid")
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        attached = subprocess.Popen([TMUX, "-S", str(socket), "attach-session", "-t", "source"],
                                    env=env, stdin=slave, stdout=slave, stderr=slave)
        wait_for(lambda: tmux("list-clients", "-F", "#{client_name}"), "client did not attach")
        client = tmux("list-clients", "-F", "#{client_name}")
        screen = bytearray()

        # With no mark, never fall back to tmux's implicit source pane.
        activate(target)
        before = snapshot()
        for key in ("j", "J"):
            screen.clear()
            press(key)
            wait_for(lambda: screen_contains("Mark a pane with prefix+m"), "missing-mark guidance absent")
            assert snapshot() == before

        # Mark via the native binding, then pull below a pane in another window.
        activate(source)
        press("m")
        wait_for(lambda: field(source, "pane_marked") == "1", "native mark key failed")
        activate(target)
        press("j")
        wait_for(lambda: field(source, "window_id") == field(target, "window_id"), "vertical join failed")
        assert int(field(source, "pane_top")) > int(field(target, "pane_top"))
        assert field(source, "pane_pid") == original_pid
        assert field(target, "pane_pid") == target_pid

        # Same-window repositioning remains possible, preserving both processes.
        tmux("select-pane", "-m", "-t", source)
        activate(target)
        press("J")
        wait_for(lambda: int(field(source, "pane_left")) > int(field(target, "pane_left")), "same-window join failed")
        assert field(source, "pane_pid") == original_pid

        # Marked pane can move across sessions. Its emptied old window/session
        # follows tmux's ordinary lifecycle rather than respawning any process.
        elsewhere = tmux("new-session", "-d", "-s", "elsewhere", "-P", "-F", "#{pane_id}",
                         "-x", "120", "-y", "40", *command)
        tmux("select-pane", "-m", "-t", source)
        activate(elsewhere)
        press("J")
        wait_for(lambda: field(source, "session_id") == field(elsewhere, "session_id"), "cross-session join failed")
        assert int(field(source, "pane_left")) > int(field(elsewhere, "pane_left"))
        assert field(source, "pane_pid") == original_pid

        # Joining a marked pane into itself is a native error, never a mutation.
        tmux("select-pane", "-m", "-t", source)
        activate(source)
        before = snapshot()
        screen.clear()
        press("j")
        wait_for(lambda: screen_contains("Source and target panes must be different"), "self-join error absent")
        assert snapshot() == before
        press("M")
        wait_for(lambda: field(source, "pane_marked_set") == "0", "native clear-mark key failed")
    finally:
        if attached:
            attached.terminate()
            attached.wait(timeout=5)
        subprocess.run([TMUX, "-S", str(socket), "kill-server"], env=env, capture_output=True)
        for fd in (master, slave):
            if fd is not None:
                os.close(fd)
print("Pane movement: actual keys, guarded absence, both layouts, same-window/cross-session moves and process identity passed")
