#!/usr/bin/env python3
"""Run the done plugin and the Seele notification hook in real fish.

Usage: DONE_PLUGIN=/path/to/done/conf.d/done.fish python3 test_hook.py

`fish`, `bash` and `timeout` come from PATH. hyprctl, notify-send,
seele-control and tmux are recording stubs, so nothing reaches a desktop.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

LEAF = Path(__file__).resolve().parent.parent / 'command-notifications.nix'


def main():
    fish, bash, timeout = (shutil.which(name) for name in ('fish', 'bash', 'timeout'))
    plugin_source = os.environ.get('DONE_PLUGIN')
    if not fish or not bash or not timeout or not plugin_source:
        raise SystemExit('fish, bash, timeout and DONE_PLUGIN=<done.fish> are required')
    leaf = LEAF.read_text()
    script = re.search(r"writeShellScript \"seele-command-done\" ''\n(.*?)\n      '';", leaf, re.S).group(1)
    script = '\n'.join(line[8:] if line.startswith(' ' * 8) else line for line in script.splitlines())
    fish_command = re.search(r"set -g __done_notification_command '(.*)'", leaf).group(1)
    minimum = int(re.search(r'set -g __done_min_cmd_duration (\d+)', leaf).group(1))

    with tempfile.TemporaryDirectory(prefix='seele-command-done-') as temp:
        root = Path(temp)
        stubs = root / 'bin'
        stubs.mkdir()
        log = root / 'log'

        def stub(name, body):
            path = stubs / name
            path.write_text(f'#!{bash}\n{body}\n')
            path.chmod(0o755)
            return str(path)

        record = f'printf "%s %s\\n" "$(basename "$0")" "$(printf "[%s]" "$@")" >> {log}'
        # hyprctl reports whichever window the test marks as focused.
        stub('hyprctl', f'echo "Window $(cat {root}/focused) -> title:"')
        notify = stub('notify-send', f'{record}; cat {root}/action')
        control = stub('seele-control', record)
        tmux = stub('tmux', f'{record}; [ "$1" = lsw ] && echo "[3]"; true')
        rendered = (script
                    .replace('${pkgs.coreutils}/bin/timeout', timeout)
                    .replace('${pkgs.libnotify}/bin/notify-send', notify)
                    .replace('${selfPackages.seele-shell}/bin/seele-control', control)
                    .replace('${lib.getExe config.programs.tmux.package}', tmux))
        assert not re.search(r'\$\{(?!window|pane)', rendered), rendered
        hook = root / 'seele-command-done'
        hook.write_text(f'#!{bash}\n{rendered}\n')
        hook.chmod(0o755)
        # `emit` cannot hand a command's exit status to the handler, so the copy
        # under test reads it from a variable the fixture sets instead.
        plugin = root / 'done.fish'
        source = Path(plugin_source).read_text()
        assert source.count('set -l exit_status $status') == 1
        plugin.write_text(source.replace('set -l exit_status $status', 'set -l exit_status $__test_status'))

        def quote(text):
            return "'" + text.replace('\\', '\\\\').replace("'", "\\'") + "'"

        def run(start, end, duration, status, command, pane=None, action='default'):
            log.write_text('')
            (root / 'action').write_text(action)
            (root / 'focused').write_text(start)
            env = {key: value for key, value in os.environ.items()
                   if key not in ('SSH_CLIENT', 'TMUX', 'TMUX_PANE')}
            env.update(PATH=f'{stubs}:{os.environ["PATH"]}', HOME=str(root), TERM='xterm',
                       XDG_CONFIG_HOME=str(root / 'config'), HYPRLAND_INSTANCE_SIGNATURE='fixture')
            if pane:
                env.update(TMUX='/nonexistent/default,1,0', TMUX_PANE=pane)
            program = f'''
source {plugin}
set -g __done_min_cmd_duration {minimum}
set -g __done_notification_command {quote(fish_command.replace('${notify}', str(hook)))}
emit fish_preexec {quote(command)}
echo {end} > {root}/focused
set -g cmd_duration {duration}
set -g __test_status {status}
emit fish_postexec {quote(command)}
'''
            result = subprocess.run([fish, '--no-config', '-i', '-c', program], env=env,
                                    capture_output=True, text=True, timeout=20)
            assert result.returncode == 0, result.stderr
            # The hook is disowned; give it time to write its record.
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and action and 'notify-send' in log.read_text() \
                    and 'seele-control' not in log.read_text():
                time.sleep(0.05)
            time.sleep(0.2)
            return log.read_text()

        out = run('aaa111', 'bbb222', 12000, 0, 'cargo build')
        assert ('notify-send [--app-name=Ghostty][--icon=com.mitchellh.ghostty]'
                '[--action=default=Show][--][Done in 12s]') in out, out
        assert 'seele-control [vicinae-focus][window][0xaaa111]' in out, out
        assert 'tmux' not in out, out

        assert run('aaa111', 'aaa111', 60000, 0, 'cargo build') == ''
        assert run('aaa111', 'bbb222', minimum - 1, 0, 'cargo build') == ''
        assert run('aaa111', 'bbb222', 20000, 0, 'git log') == ''

        marker = root / 'EXECUTED'
        hostile = f'make; echo $(touch {marker}) "quoted" \\ `touch {marker}` *'
        out = run('ccc333', 'ddd444', 125000, 2, hostile, pane='%7')
        assert '[Failed (2) after 2m 5s]' in out, out
        assert '--urgency' not in out and 'transient' not in out, out
        assert f'echo $(touch {marker}) "quoted"' in out, out
        assert not marker.exists(), 'the command line was evaluated'
        assert 'seele-control [vicinae-focus][window][0xccc333]' in out, out
        assert 'tmux [select-window][-t][%7]' in out and 'tmux [select-pane][-t][%7]' in out, out

        out = run('aaa111', 'bbb222', 20000, 0, 'nix build', action='')
        assert 'notify-send' in out and 'seele-control' not in out and 'select-' not in out, out
    print('Command notifications: focus, threshold, exclusion, quoting, failure and Show checks passed')


if __name__ == '__main__':
    main()
