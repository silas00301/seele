"""Exercise edit with real Fish and a private argument-recording editor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

body, fish = sys.argv[1:]
fish = shutil.which(fish)
assert fish, "Fish must be available"

with tempfile.TemporaryDirectory(prefix="seele-fish-edit-") as temporary:
    base = Path(temporary)
    home = base / "home"
    home.mkdir()
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("XDG_", "FISH_")) and key not in ("EDITOR", "VISUAL")}
    env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
               XDG_CACHE_HOME=str(home / "cache"), XDG_DATA_HOME=str(home / "data"))
    function = base / "edit.fish"
    function.write_text("function edit\n" + Path(body).read_text() + "end\n")
    editor = base / "fixture-editor"
    editor.write_text(f"#!{sys.executable}\n" +
                      "import json, os, sys\n" +
                      "print(json.dumps(sys.argv[1:]))\n" +
                      "print(sys.stdin.read(), end='')\n" +
                      "sys.exit(int(os.environ.get('EDITOR_STATUS', '0')))\n")
    editor.chmod(0o700)
    spaced = base / "editor with 'quotes'"
    spaced.symlink_to(editor)
    env["TEST_FUNCTION"] = str(function)
    env["PATH"] = str(base) + os.pathsep + env["PATH"]
    script = 'source "$TEST_FUNCTION"; edit $argv'
    cases = 0

    def check(command, args=(), expected=None, status=0, stdin="", extra=None):
        global cases
        current = dict(env)
        if command is not None:
            current["EDITOR"] = command
        current.update(extra or {})
        result = subprocess.run([fish, "--no-config", "-c", script, "--", *args],
                                cwd=base, env=current, input=stdin, text=True,
                                capture_output=True)
        assert result.returncode == status, (command, result)
        if expected is None:
            assert not result.stdout and result.stderr, result
        else:
            line, remaining = result.stdout.split("\n", 1)
            assert json.loads(line) == expected, (command, args, result.stdout)
            assert remaining == stdin, "editor must inherit untouched standard input"
            assert not result.stderr, result.stderr
        assert not (base / "sentinel").exists(), "shell syntax must never execute"
        cases += 1

    filenames = ["two words.txt", "quote'and\".txt", "$HOME.txt", "$(touch sentinel)",
                 "(touch sentinel)", "; touch sentinel", "*.txt", "back\\slash.txt", "line\nbreak.txt", ""]
    check(str(editor), filenames, filenames, stdin="editor input\n")
    check("fixture-editor --wait", filenames, ["--wait", *filenames])
    check(f'{editor} --label "two words" --empty ""', ["file"],
          ["--label", "two words", "--empty", "", "file"])
    check(f"{editor} escaped\\ argument 'single quoted'", (),
          ["escaped argument", "single quoted"])
    # read --tokenize deliberately tolerates unfinished quotes like Fish's
    # own editor helpers; this remains literal argument parsing, never eval.
    check(f'{editor} "unfinished (touch sentinel)', (),
          ["unfinished (touch sentinel)"])
    # A raw executable path worked in the original helper; keep that behavior.
    check(str(spaced), ["file"], ["file"])
    quoted = str(spaced).replace("'", "\\'")
    check(f"'{quoted}' --wait", ["file"], ["--wait", "file"])
    check(str(editor), ["--", "-filename"], ["--", "-filename"])
    check(str(editor), (), [])
    check(str(editor), ["file"], ["file"], status=23, extra={"EDITOR_STATUS": "23"})
    check(str(editor), ["file"], ["file"], extra={"VISUAL": "not-the-chosen-editor"})
    # EDITOR words are tokenized, never evaluated as a shell script.
    check(f"{editor} (touch sentinel) $HOME *.txt ; touch sentinel", (),
          ["(touch sentinel)", "$HOME", "*.txt", ";", "touch", "sentinel"])
    for command in (None, "", "   ", "''"):
        check(command, status=2)
    check("no-such-editor-seele-fixture", status=127)
    print(f"Fish edit: {cases} cases passed")
