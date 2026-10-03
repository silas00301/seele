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
                   XDG_RUNTIME_DIR=str(runtime), HOME=str(root / "home"),
                   XDG_CONFIG_HOME=str(root / "custom-config"),
                   GH_CONFIG_DIR=str(root / "custom-gh"),
                   DOCKER_CONFIG=str(root / "custom-docker"),
                   NVIM_LOG_FILE=str(runtime / "nvim.log"))
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
                     ".kube/config", ".config/sops/age/keys.txt", "runtime/secret.txt",
                     ".netrc", ".npmrc", ".pypirc", ".git-credentials",
                     ".config/gh/hosts.yml", ".docker/config.json",
                     "custom-config/gh/hosts.yml", "custom-gh/hosts.yml",
                     "custom-docker/config.json"]:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("before\n")
            run([edit(path), "call assert_false(&l:undofile)",
                 "call setline(1, 'sensitive fixture')", "write",
                 "call assert_false(filereadable(undofile(expand('%:p'))))"])

        # Similar names and adjacent tool settings are ordinary editable files.
        for name in ["npmrc", ".npmrc.example", ".netrc.notes", ".git-credentials.bak",
                     ".config/gh/config.yml", ".docker/daemon.json",
                     "custom-config/other/hosts.yml", "custom-gh/config.yml",
                     "custom-docker/other.json", "gh/hosts.yml", "docker/config.json"]:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("before\n")
            run([edit(path), "call assert_true(&l:undofile)",
                 "call setline(1, 'ordinary fixture')", "write",
                 "call assert_true(filereadable(undofile(expand('%:p'))))"])

        # A regular-looking symlink must inherit its secret target's exclusion.
        link = root / "linked.txt"
        link.symlink_to(root / ".env")
        run([edit(link), "call assert_false(&l:undofile)"])
        auth_link = root / "auth-link.txt"
        auth_link.symlink_to(root / "custom-gh" / "hosts.yml")
        run([edit(auth_link), "call assert_false(&l:undofile)",
             "call setline(1, 'linked sensitive fixture')", "write",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])

        # BufWritePre must protect an alternate :write target too.
        alternate = root / "alternate.txt"
        alternate.write_text("before\n")
        run([edit(alternate), "call assert_true(&l:undofile)",
             "call setline(1, 'alternate sensitive fixture')",
             "execute 'write! ' .. fnameescape(" + vim_string(root / ".npmrc") + ")",
             "call assert_false(&l:undofile)",
             "call assert_false(filereadable(undofile(" + vim_string(root / ".npmrc") + ")))"])

        # BufFilePost protects a rename before a new sensitive file is written.
        run([edit(alternate), "call assert_true(&l:undofile)",
             "call setline(1, 'renamed sensitive fixture')",
             "execute 'file ' .. fnameescape(" + vim_string(root / "custom-docker" / "config.json") + ")",
             "call assert_false(&l:undofile)", "write!",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])

        # Default config home still applies when XDG_CONFIG_HOME is unset.
        env.pop("XDG_CONFIG_HOME")
        default_auth = root / "home" / ".config" / "gh" / "hosts.yml"
        default_auth.parent.mkdir(parents=True)
        default_auth.write_text("before\n")
        run([edit(default_auth), "call assert_false(&l:undofile)",
             "call setline(1, 'default sensitive fixture')", "write",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])
        env["XDG_CONFIG_HOME"] = str(root / "custom-config")

        # A sensitive display name must stay excluded even with a normal target.
        displayed_auth = root / "nested" / ".netrc"
        displayed_auth.parent.mkdir()
        displayed_auth.symlink_to(ordinary)
        run([edit(displayed_auth), "call assert_false(&l:undofile)"])

        # Custom auth directories may themselves be symlinked.
        actual_gh = root / "actual-gh"
        actual_gh.mkdir()
        actual_auth = actual_gh / "hosts.yml"
        actual_auth.write_text("before\n")
        linked_gh = root / "linked-gh"
        linked_gh.symlink_to(actual_gh, target_is_directory=True)
        env["GH_CONFIG_DIR"] = str(linked_gh)
        run([edit(actual_auth), "call assert_false(&l:undofile)",
             "call setline(1, 'resolved sensitive fixture')", "write",
             "call assert_false(filereadable(undofile(expand('%:p'))))"])
        env["GH_CONFIG_DIR"] = str(root / "custom-gh")

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
