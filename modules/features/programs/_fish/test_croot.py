"""Exercise the shipped Fish function in real, private VCS worktrees."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

body, fish, jj, git = sys.argv[1:]
fish, jj, git = (shutil.which(command) for command in (fish, jj, git))
assert all((fish, jj, git)), "Fish, Jujutsu and Git must be available"

with tempfile.TemporaryDirectory(prefix="seele-croot-") as temporary:
    base = Path(temporary).resolve()
    home = base / "home"
    home.mkdir()
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("GIT_", "JJ_", "XDG_", "FISH_"))}
    env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
               XDG_CACHE_HOME=str(home / "cache"), XDG_DATA_HOME=str(home / "data"),
               JJ_CONFIG=str(base / "jj.toml"), GIT_CONFIG_NOSYSTEM="1",
               GIT_CONFIG_GLOBAL=os.devnull, LC_ALL="C.UTF-8")
    (base / "jj.toml").write_text('[user]\nname = "Fixture"\nemail = "fixture@example.invalid"\n')
    function = base / "croot.fish"
    function.write_text("function croot\n" + Path(body).read_text() + "end\n")
    env["TEST_FUNCTION"] = str(function)
    fixture_path = base / "bin"
    fixture_path.mkdir()
    for name, executable in (("jj", jj), ("git", git)):
        (fixture_path / name).symlink_to(executable)
    normal_path = str(fixture_path) + os.pathsep + env["PATH"]
    env["PATH"] = normal_path

    def run(argv, cwd):
        return subprocess.run(argv, cwd=cwd, env=env, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

    script = '''source "$TEST_FUNCTION"
builtin cd -- "$TEST_START"; or exit 90
# Neither a user cd function nor CDPATH may redirect navigation.
function cd; return 91; end
set -gx CDPATH "$TEST_CDPATH"
croot $argv
set -l result $status
printf '\\0%s\\0%s\\0' "$result" "$PWD"
'''
    cases = 0

    def check(start, expected=None, status=0, args=(), path=None):
        nonlocal_env = dict(env, TEST_START=str(start), TEST_CDPATH=str(base / "decoy"))
        if path is not None:
            nonlocal_env["PATH"] = path
        result = subprocess.run([fish, "--no-config", "-c", script, "--", *args],
                                env=nonlocal_env, cwd=base, capture_output=True, check=True)
        output, code, directory, end = result.stdout.split(b"\0")
        assert int(code) == status, (start, args, result.stdout, result.stderr)
        assert directory == os.fsencode(expected or start), (start, args, directory, expected)
        assert end == b""
        if status:
            assert result.stderr, "failures must be explained"
        elif not args:
            assert not output and not result.stderr, (output, result.stderr)
        return 1

    root = base / "-jj project 'quoted' $literal"
    run([jj, "git", "init", str(root)], base)
    nested = root / "nested" / "deep"
    nested.mkdir(parents=True)
    (root / "untracked.txt").write_text("must not be snapshotted\n")
    operation_before = run([jj, "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id", "-n", "1"], root)
    cases += check(nested, root)
    cases += check(root, root)
    operation_after = run([jj, "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id", "-n", "1"], root)
    assert operation_before == operation_after, "navigation must not snapshot a dirty workspace"

    # A colocated repository still prefers its Jujutsu workspace root and
    # must leave both the operation head and Git index unchanged.
    colocated = base / "colocated"
    run([jj, "git", "init", "--colocate", str(colocated)], base)
    (colocated / "nested").mkdir()
    (colocated / "dirty.txt").write_text("not a navigation side effect\n")
    index = colocated / ".git" / "index"
    before_index = index.read_bytes() if index.exists() else None
    before_op = run([jj, "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id", "-n", "1"], colocated)
    cases += check(colocated / "nested", colocated)
    assert before_op == run([jj, "op", "log", "--ignore-working-copy", "--no-graph", "-T", "id", "-n", "1"], colocated)
    assert before_index == (index.read_bytes() if index.exists() else None)

    linked = base / "linked jj workspace"
    run([jj, "workspace", "add", "--name", "fixture-linked", str(linked)], root)
    linked_nested = linked / "nested"
    linked_nested.mkdir()
    cases += check(linked_nested, linked)
    link = base / "symbolic directory"
    link.symlink_to(nested, target_is_directory=True)
    cases += check(link, root)

    git_root = base / "git [project]"
    run([git, "init", "--quiet", str(git_root)], base)
    git_nested = git_root / "one" / "two"
    git_nested.mkdir(parents=True)
    cases += check(git_nested, git_root)
    run([git, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "-m", "fixture"], git_root)
    git_linked = base / "linked git worktree"
    run([git, "worktree", "add", "--detach", str(git_linked)], git_root)
    (git_linked / "nested").mkdir()
    cases += check(git_linked / "nested", git_linked)

    # Literal newline names must not be split or trimmed by Fish substitution.
    for vcs, name in ((jj, "jj\\nline\\n"), (git, "git\\nline\\n")):
        newline_root = base / name.replace("\\n", "\n")
        argv = [jj, "git", "init", str(newline_root)] if vcs == jj else [git, "init", "--quiet", str(newline_root)]
        run(argv, base)
        (newline_root / "nested").mkdir()
        cases += check(newline_root / "nested", newline_root)

    outside = base / "outside"
    outside.mkdir()
    cases += check(outside, status=1)
    bare = base / "bare.git"
    run([git, "init", "--bare", "--quiet", str(bare)], base)
    cases += check(bare, status=1)
    for args in (("--bad",), ("somewhere",), ("",), ("--help", "extra")):
        cases += check(nested, status=2, args=args)
    for args in (("-h",), ("--help",)):
        cases += check(outside, args=args)

    # No jj on PATH: a Git project must still work; neither tool: clean failure.
    git_only = base / "git-only"
    git_only.mkdir()
    (git_only / "git").symlink_to(git)
    cases += check(git_nested, git_root, path=str(git_only))
    empty_path = base / "empty-bin"
    empty_path.mkdir()
    cases += check(outside, status=1, path=str(empty_path))

    # A failed producer must not redirect cwd even if it printed a valid path.
    fake = base / "fake-bin"
    fake.mkdir()
    for name in ("jj", "git"):
        executable = fake / name
        executable.write_text(f"#!{sys.executable}\nimport sys\nprint({str(root)!r})\nsys.exit(1)\n")
        executable.chmod(0o755)
    cases += check(outside, status=1, path=str(fake))
    # A successful but malformed lookup is not a directory change either.
    (fake / "jj").write_text(f"#!{sys.executable}\nprint('relative-root')\n")
    cases += check(outside, status=1, path=str(fake))
    (fake / "jj").write_text(f"#!{sys.executable}\nprint({str(base / 'gone')!r})\n")
    cases += check(outside, status=1, path=str(fake))
    print(f"croot: {cases} real Fish navigation cases passed; Jujutsu history unchanged")
