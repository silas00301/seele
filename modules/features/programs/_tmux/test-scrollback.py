#!/usr/bin/env python3
"""Exercise real tmux and Neovim with a private server and synthetic output only."""
import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

TMUX = shutil.which(os.environ.get("TMUX_BIN", "tmux"))
NVIM = shutil.which(os.environ.get("NVIM_BIN", "nvim"))
assert TMUX and NVIM, "tmux and Neovim are required"
VIEWER = Path(__file__).with_name("scrollback.lua").resolve()


def wait_for(check, description):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.03)
    raise AssertionError(description)


with tempfile.TemporaryDirectory(prefix="scb-") as temporary:
    root = Path(temporary)
    home = root / "home"
    home.mkdir()
    socket = root / "s ' $(touch INJECTED)"
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
               XDG_STATE_HOME=str(home / "state"), XDG_CACHE_HOME=str(home / "cache"),
               NVIM_LOG_FILE=os.devnull, TERM="xterm-256color")
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)

    def tmux(*args, **kwargs):
        return subprocess.run([TMUX, "-S", str(socket), *args], env=env,
                              check=True, capture_output=True, **kwargs).stdout.decode()

    config = root / "tmux.conf"
    config.write_text("set -g history-limit 15000\nset -g prefix C-s\n"
                      "set -g set-clipboard external\n"
                      "set -as terminal-features ',xterm*:clipboard'\n")
    master = slave = None
    attached = None
    try:
        pane = tmux("-f", str(config), "new-session", "-d", "-P", "-F", "#{pane_id}",
                    "-x", "80", "-y", "24", "-c", str(root), sys.executable, "-u", "-c",
                    "import time; print('HISTORY_SENTINEL'); "
                    "[print('row-%05d' % i) for i in range(120)]; "
                    "print('WRAPPED:' + 'x' * 190); print('hard-newline'); "
                    "print('COPY_SENTINEL'); print('vim: set modifiable modeline:'); "
                    "time.sleep(120)").strip()
        wait_for(lambda: "COPY_SENTINEL" in tmux("capture-pane", "-p", "-S", "-", "-t", pane),
                 "synthetic pane did not render")
        other = tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                     sys.executable, "-u", "-c", "import time; print('WRONG_PANE'); time.sleep(120)").strip()
        # Change the active window before capture: the viewer must retain its pane ID.
        tmux("select-window", "-t", other)
        master, slave = pty.openpty()
        # A real attached terminal supplies a client for load-buffer -w and the popup.
        import fcntl
        import struct
        import termios
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        attached = subprocess.Popen([TMUX, "-S", str(socket), "attach-session"],
                                    env=env, stdin=slave, stdout=slave, stderr=slave)
        wait_for(lambda: bool(tmux("list-clients", "-F", "#{client_name}").strip()), "client missing")
        client = tmux("list-clients", "-F", "#{client_name}").strip()
        viewenv = dict(env, SEELE_SCROLLBACK_TMUX=TMUX, SEELE_SCROLLBACK_SOCKET=str(socket),
                       SEELE_SCROLLBACK_PANE=pane, SEELE_SCROLLBACK_CLIENT=client)
        tmux("set-buffer", "UNCHANGED")
        original = tmux("capture-pane", "-p", "-S", "-", "-J", "-t", pane)
        original_state = tmux("list-panes", "-a", "-F", "#{pane_id}:#{pane_active}:#{pane_pid}")

        def nvim(lua, extra_env=None):
            return subprocess.run([NVIM, "--headless", "--noplugin", "-n", "-i", "NONE", "-R",
                                   "-u", str(VIEWER), "-c", "lua " + lua],
                                  env=extra_env or viewenv, capture_output=True, timeout=12)

        # Real buffer, exact wraps/newlines, isolated options, search, and dismissal.
        expected = original[:-1].split("\n")
        assertions = (
            "assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0,0,-1,false), "
            + "vim.json.decode(" + json.dumps(json.dumps(expected)) + "))); "
            "assert(not vim.bo.modifiable and vim.bo.readonly and not vim.bo.swapfile); "
            "assert(not vim.bo.undofile and vim.bo.buftype == 'nofile'); "
            "assert(vim.o.shada == '' and not vim.o.modeline and not vim.o.exrc); "
            "assert(vim.o.clipboard == '' and vim.o.undolevels == -1); "
            "assert(vim.fn.search('HISTORY_SENTINEL', 'w') > 0); "
            "assert(vim.fn.search('WRONG_PANE', 'w') == 0); "
            "vim.cmd('qall!')"
        )
        result = nvim(assertions)
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "UNCHANGED"
        assert tmux("capture-pane", "-p", "-S", "-", "-J", "-t", pane) == original
        assert tmux("list-panes", "-a", "-F", "#{pane_id}:#{pane_active}:#{pane_pid}") == original_state
        assert not list(home.rglob("*")), "viewer wrote persistent home files"

        # Explicit linewise yank preserves its trailing newline and closes the viewer.
        result = nvim("assert(vim.fn.search('^COPY_SENTINEL$', 'w') > 0); vim.cmd('normal! yy')")
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "COPY_SENTINEL\n"
        # Character selection does not acquire a linewise newline.
        result = nvim("assert(vim.fn.search('^COPY_SENTINEL$', 'w') > 0); vim.cmd('normal! 0v3ly')")
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "COPY"
        # A rectangle keeps row separators without inventing a trailing newline.
        result = nvim("assert(vim.fn.search('^row-00098$', 'w') > 0); "
                      "vim.cmd('normal! 0' .. vim.api.nvim_replace_termcodes('<C-v>', true, false, true) .. 'jy')")
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "r\nr"
        tmux("set-buffer", "COPY")
        # A vanished pane produces an error buffer, never the newly active pane.
        result = nvim("assert(vim.api.nvim_get_current_line():match('Cannot capture')); vim.cmd('qall!')",
                      dict(viewenv, SEELE_SCROLLBACK_PANE="%9999999"))
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "COPY"

        # Limits are exercised against real history, not a mocked capture command.
        bounded = tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                       sys.executable, "-u", "-c",
                       "import time; [print('limit-%05d' % i) for i in range(12000)]; "
                       "print('\\033]2;HISTORY_READY\\007', end='', flush=True); time.sleep(120)").strip()
        wait_for(lambda: tmux("display-message", "-p", "-t", bounded, "#{pane_title}").strip() == "HISTORY_READY",
                 "bounded history fixture did not render")
        result = nvim("assert(vim.fn.search('limit-00000', 'w') == 0); "
                      "assert(vim.fn.search('limit-11999', 'w') > 0); vim.cmd('qall!')",
                      dict(viewenv, SEELE_SCROLLBACK_PANE=bounded))
        assert result.returncode == 0, result.stderr.decode()
        oversized = tmux("new-window", "-d", "-P", "-F", "#{pane_id}",
                         sys.executable, "-u", "-c",
                         "import time; time.sleep(0.3); [print('x' * 1900) for i in range(5000)]; "
                         "print('\\033]2;BYTES_READY\\007', end='', flush=True); time.sleep(120)").strip()
        tmux("set-window-option", "-t", oversized, "window-size", "manual")
        tmux("resize-window", "-t", oversized, "-x", "2000", "-y", "24")
        wait_for(lambda: tmux("display-message", "-p", "-t", oversized, "#{pane_title}").strip() == "BYTES_READY",
                 "oversized history fixture did not render")
        result = nvim("assert(vim.api.nvim_get_current_line():match('exceeds 8 MiB')); vim.cmd('qall!')",
                      dict(viewenv, SEELE_SCROLLBACK_PANE=oversized))
        assert result.returncode == 0, result.stderr.decode()
        assert tmux("show-buffer") == "COPY"

        # Exercise the actual Nix launcher and binding with its store paths substituted.
        source = VIEWER.parent.parent.joinpath("tmux.nix").read_text()
        script = source.split('pkgs.writeShellScript "seele-tmux-scrollback" \'\'', 1)[1].split("\n      '';", 1)[0]
        script = script.replace("${pkgs.tmux}/bin/tmux", shlex.quote(TMUX))
        script = script.replace("${pkgs.neovim-unwrapped}/bin/nvim", shlex.quote(NVIM))
        script = script.replace("${./_tmux/scrollback.lua}", shlex.quote(str(VIEWER)))
        launcher = root / "viewer"
        launcher.write_text("#!" + shutil.which("bash") + "\n" + script)
        launcher.chmod(0o700)
        binding = next(line.strip() for line in source.splitlines() if "bind-key -N" in line)
        binding = binding.replace("${scrollback}", str(launcher))
        tmux("source-file", "-", input=(binding + "\n").encode())
        tmux("select-window", "-t", pane)
        os.write(master, b"\x13H")
        terminal = bytearray()

        def read_until_visible():
            if select.select([master], [], [], 0.05)[0]:
                terminal.extend(os.read(master, 65536))
            return b"copy and close" in terminal

        wait_for(read_until_visible, "popup did not start")
        assert b"\x1b]52;;Q09QWQ==" in terminal, "copy did not reach terminal OSC 52"
        os.write(master, b"q")
        time.sleep(0.15)
        assert tmux("show-buffer") == "COPY"
        assert "Search and copy pane scrollback" in tmux("list-keys", "-N")
        assert not list(home.rglob("*")), "popup wrote persistent home files"
        assert not (root / "INJECTED").exists()
        print("PASS: exact pane/history/wraps, scratch isolation, search, cancel, explicit copies, vanished pane, history/byte bounds, terminal clipboard, real popup")
    finally:
        subprocess.run([TMUX, "-S", str(socket), "kill-server"], env=env, capture_output=True)
        if attached:
            attached.wait(timeout=5)
        if master is not None:
            os.close(master)
        if slave is not None:
            os.close(slave)
