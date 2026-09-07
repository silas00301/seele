#!/usr/bin/env python3
"""Exercise real editor undo writes with isolated, self-cleaning file fixtures.

Run from a writable directory outside temporary/runtime paths. Neovim is used
when available; Vim can test the shared undo engine after substituting only
Neovim's stdpath('state') lookup. Neither mode loads the user's configuration.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def vim_string(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    editor = shutil.which("nvim") or shutil.which("vim")
    if editor is None:
        raise SystemExit("Neovim or Vim is required")
    neovim = Path(editor).name == "nvim"
    source = Path(__file__).with_name("undo.vim").read_text()
    if not neovim:
        source = source.replace("stdpath('state')", "($XDG_STATE_HOME .. '/nvim')")

    with tempfile.TemporaryDirectory(prefix=".seele-undo-test-", dir=Path.cwd()) as root:
        root = Path(root)
        state = root / "state"
        undo = state / "nvim" / "undo"
        runtime = root / "runtime"
        runtime.mkdir()
        config = root / "undo.vim"
        config.write_text(source)
        env = dict(os.environ, XDG_STATE_HOME=str(state), TMPDIR=str(runtime),
                   XDG_RUNTIME_DIR=str(runtime))
        count = 0

        def run(commands, *, isolated_config=config):
            nonlocal count
            count += 1
            errors = root / "errors"
            errors.unlink(missing_ok=True)
            script = root / "test.vim"
            script.write_text(
                "set nomore\n"
                + "execute 'source ' .. fnameescape(" + vim_string(isolated_config) + ")\n"
                + "\n".join(commands)
                + "\nif !empty(v:errors)\n"
                + "  call writefile(v:errors, " + vim_string(errors) + ")\n"
                + "  cquit\nendif\nqa!\n"
            )
            args = ([editor, "--headless", "-u", "NONE"] if neovim else
                    [editor, "-Nu", "NONE", "-U", "NONE", "-es"])
            result = subprocess.run(args + ["-i", "NONE", "-n", "-S", str(script)],
                                    env=env, capture_output=True, text=True)
            if result.returncode:
                raise AssertionError((errors.read_text() if errors.exists() else "")
                                     + result.stdout + result.stderr)

        def edit(path):
            return "execute 'edit ' .. fnameescape(" + vim_string(path) + ")"

        ordinary = root / "ordinary.txt"
        ordinary.write_text("first\n")
        run([edit(ordinary), "call assert_true(&l:undofile)",
             "call setline(1, 'second')", "write"])
        assert undo.stat().st_mode & 0o777 == 0o700
        assert len(list(undo.iterdir())) == 1
        run([edit(ordinary), "undo", "call assert_equal('first', getline(1))"])

        # Tighten a pre-existing directory as well as creating new ones privately.
        undo.chmod(0o755)
        run(["call assert_true(&undofile)"])
        assert undo.stat().st_mode & 0o777 == 0o700

        for name in [".env", ".env.production", "client.pem", "client.key", "note.gpg",
                     ".ssh/id_ed25519", ".gnupg/plaintext", ".aws/credentials",
                     ".kube/config", ".config/sops/age/keys.txt", "runtime/secret.txt"]:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("before\n")
            run([edit(path), "call assert_false(&l:undofile)",
                 "call setline(1, 'sensitive fixture')", "write",
                 "call assert_false(filereadable(undofile(expand('%:p'))))"])

        # A regular-looking symlink must inherit its secret target's exclusion.
        link = root / "linked.txt"
        link.symlink_to(root / ".env")
        run([edit(link), "call assert_false(&l:undofile)"])

        opted_out = root / "opted-out.txt"
        opted_out.write_text("before\n")
        run([edit(opted_out), "setlocal noundofile", "call setline(1, 'private')", "write",
             "call assert_false(&l:undofile)",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])

        renamed = root / "renamed.txt"
        renamed.write_text("before\n")
        run([edit(renamed), "call setline(1, 'private')",
             "execute 'file ' .. fnameescape(" + vim_string(root / ".env.renamed") + ")",
             "call assert_false(&l:undofile)", "write",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])

        # A secret buffer must not switch persistence off for subsequent files.
        run([edit(root / ".env"), "call assert_false(&l:undofile)",
             edit(ordinary), "call assert_true(&l:undofile)"])

        with tempfile.TemporaryDirectory(prefix="seele-undo-excluded-", dir="/tmp") as temp:
            path = Path(temp) / "sensitive.txt"
            path.write_text("before\n")
            run([edit(path), "call assert_false(&l:undofile)"])

        # An unusable or symlinked state location must fail closed.
        blocked_state = root / "blocked-state"
        blocked_state.mkdir()
        (blocked_state / "nvim").write_text("not a directory")
        env["XDG_STATE_HOME"] = str(blocked_state)
        run(["call assert_false(&undofile)"])
        linked_state = root / "linked-state" / "nvim"
        linked_state.mkdir(parents=True)
        (linked_state / "undo").symlink_to(undo, target_is_directory=True)
        env["XDG_STATE_HOME"] = str(linked_state.parent)
        run(["call assert_false(&undofile)"])
        print(f"Passed {count} editor sessions ({'Neovim' if neovim else 'Vim compatibility mode'}).")


if __name__ == "__main__":
    main()
