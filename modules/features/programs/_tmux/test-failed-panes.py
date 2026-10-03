"""Exercise failed-pane policy and the real recovery keys on a private tmux server."""
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

policy, tmux_bin, fish = sys.argv[1:]
tmux_bin, fish = (shutil.which(command) for command in (tmux_bin, fish))
assert tmux_bin and fish, "tmux and Fish are required"


def wait_for(check, description):
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.025)
    raise AssertionError(description)


with tempfile.TemporaryDirectory(prefix="seele-tmux-exit-") as temporary:
    root = Path(temporary)
    home = root / "home"
    home.mkdir()
    socket = root / "server"
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
               XDG_DATA_HOME=str(home / "data"), TERM="xterm-256color")
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    config = root / "tmux.conf"
    config.write_text("set -g prefix C-s\nset -g status off\nbind-key q kill-pane\n" +
                      Path(policy).read_text())
    master = slave = None
    client = None

    def tmux(*args):
        result = subprocess.run([tmux_bin, "-S", str(socket), *args],
                                env=env, check=True, capture_output=True, text=True)
        return result.stdout.strip()

    def panes():
        return tmux("list-panes", "-a", "-F", "#{pane_id}").splitlines()

    def state(pane, field):
        return tmux("display-message", "-p", "-t", pane, "#{" + field + "}")

    def window(*command):
        return tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                    "-c", str(root), *command)

    def key(pane, character):
        tmux("select-window", "-t", pane)
        tmux("select-pane", "-t", pane)
        os.write(master, b"\x13" + character)

    def read_message(message):
        output = bytearray()

        def ready():
            readable, _, _ = select.select([master], [], [], 0.025)
            if readable:
                output.extend(os.read(master, 65536))
            return message in output

        wait_for(ready, "recovery key did not explain live-pane refusal")

    try:
        keeper = tmux("-f", str(config), "new-session", "-d", "-P", "-F", "#{pane_id}",
                      "-x", "100", "-y", "24", sys.executable, "-c",
                      "import time; time.sleep(120)")
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
        client = subprocess.Popen([tmux_bin, "-S", str(socket), "attach-session"],
                                  env=env, stdin=slave, stdout=slave, stderr=slave)
        wait_for(lambda: bool(tmux("list-clients")), "private client did not attach")

        # Successful tasks disappear; failed tasks retain their exact output/status.
        success = window(sys.executable, "-c", "print('SUCCESS'); raise SystemExit(0)")
        wait_for(lambda: success not in panes(), "successful task was retained")
        counter = root / "starts"
        failed = window(sys.executable, "-u", "-c",
                        "from pathlib import Path; "
                        f"p=Path({str(counter)!r}); "
                        "p.write_text(p.read_text()+'start\\n' if p.exists() else 'start\\n'); "
                        "print('FAILURE_SENTINEL'); raise SystemExit(23)")
        wait_for(lambda: state(failed, "pane_dead_status") == "23", "failed status missing")
        assert state(failed, "pane_dead_status") == "23"
        retained = tmux("capture-pane", "-p", "-S", "-", "-t", failed)
        assert "FAILURE_SENTINEL" in retained, repr(retained)
        assert "Exit 23" in retained and "Shift+R: restart" in retained
        key(failed, b"R")
        wait_for(lambda: counter.read_text().count("start") == 2, "dead pane did not respawn")
        wait_for(lambda: state(failed, "pane_dead") == "1", "restarted task did not exit")
        key(failed, b"q")
        wait_for(lambda: failed not in panes(), "close key did not dismiss failed pane")

        # The exact binding refuses to restart a running pane; native respawn-pane
        # also lacks -k so a check/action race cannot force-kill another command.
        original_pid = state(keeper, "pane_pid")
        key(keeper, b"R")
        read_message(b"Pane is still running")
        assert state(keeper, "pane_pid") == original_pid
        assert state(keeper, "pane_dead") == "0"

        # Fish shell exit intent is not distinguishable from other commands.
        clean_shell = window(fish, "--no-config", "-c", "exit 0")
        wait_for(lambda: clean_shell not in panes(), "clean Fish exit was retained")
        failed_shell = window(fish, "--no-config", "-c", "printf 'FISH_FAILURE\\n'; exit 17")
        wait_for(lambda: state(failed_shell, "pane_dead_status") == "17", "nonzero Fish exit lost")
        assert state(failed_shell, "pane_dead_status") == "17"
        assert "FISH_FAILURE" in tmux("capture-pane", "-p", "-S", "-", "-t", failed_shell)
        key(failed_shell, b"q")
        wait_for(lambda: failed_shell not in panes(), "nonzero Fish pane did not close")

        signaled = window(sys.executable, "-u", "-c",
                          "import os, signal; print('SIGNAL_SENTINEL'); "
                          "os.kill(os.getpid(), signal.SIGTERM)")
        wait_for(lambda: state(signaled, "pane_dead_signal") == "15", "signal failure was lost")
        assert state(signaled, "pane_dead_signal") == "15"
        assert "Signal 15" in tmux("capture-pane", "-p", "-S", "-", "-t", signaled)
        print("tmux failed panes: task/Fish exits, signal, restart, close and live refusal passed")
    finally:
        subprocess.run([tmux_bin, "-S", str(socket), "kill-server"], env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if client:
            client.wait(timeout=5)
        for descriptor in (master, slave):
            if descriptor is not None:
                os.close(descriptor)
