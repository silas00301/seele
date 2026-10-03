#!/usr/bin/env python3
"""Drive real Yazi in a private tmux server to pack and extract crafted archives.

Run with the Yazi release nixpkgs pins and the 7-Zip the `yazi` feature selects:

    YAZI_BIN=/path/to/yazi YA_BIN=/path/to/ya SEVENZIP_BIN=/path/to/7zz \
        python3 modules/features/programs/_yazi/test-archives.py

The configuration mirrors `yazi.nix`: `C` runs the packaged `pack.lua` with 7-Zip
substituted by path, `E` publishes the selection to Yazi's own `extract` plugin,
and 7-Zip is first on PATH as the nixpkgs wrapper puts it. Everything lives in a
temporary directory with its own HOME, TMPDIR and tmux socket.
"""
import base64
import gzip
import io
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import time
import zipfile

YAZI = shutil.which(os.environ.get("YAZI_BIN", "yazi"))
YA = shutil.which(os.environ.get("YA_BIN", "ya"))
SEVENZIP = shutil.which(os.environ.get("SEVENZIP_BIN", "7zz"))
TMUX = shutil.which(os.environ.get("TMUX_BIN", "tmux"))
assert YAZI and YA and SEVENZIP and TMUX, "yazi, ya, 7zz and tmux are required"
PLUGIN = Path(__file__).with_name("pack.lua").read_text().replace("@sevenzip@", SEVENZIP)
CLIENT = str(os.getpid())
# libarchive's test_read_format_rar5_compressed.rar: one 1200-byte `test.bin`
# that only a 7-Zip with the RAR decoder extracts; the free build writes it empty.
RAR5 = base64.b64decode("""
UmFyIRoHAQDz4YLrCwEFBwAGAQGAgIAAicZf2iYCAwvpAgSwCaSDAs1wynyABQEIdGVzdC5iaW4K
AxOLV6xb+BitHsr0ZQEnZWBUH1V2Xb+UknHJz2WWWQxw2WWTGMWSE4ZCSSThkJCSSSQk45JJIQhJ
JCEJJJCSSEISEs21b3t9Mw6AfR0Drj+eup/3Qf732vfdea86X+gAQAEAyCCfn49vX08vHv7uzr6u
no5+Xk4+Lh4N/d3NrZ19bV1NPS0M/NzMrJyMfGxcTDwb+9vLu5uLe2tbSzsrGvrq2rqqmnpaSjoq
Ggn52cm5mXlpSTSyUjIR6FAfjoyKiYc6cNmoaEgoB+fHt6eHZ0c3Jxb21raWdlY2FfXVtZV1VTIT
f1/I/QJT6JTn+ESXRYowZ5YXajgppimUF+ZC0XadRjLDOMCoR/+glMZpCl9lUKxWVguLAZFoNy4H
deEGwA8xBIyCeZhWNAumoZbYN5uHg4Bgcg+uYROgpnYYDwNt6Hu9h1fQjfxYQI0YMecKHk0Jg2L4
4OY6HCIEqeGFFjtjQ/nxUIBsIQ0IhNIxnJAvJQAdd1ZRAwUEAA==
""")


def wait_for(check, description, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.1)
    raise AssertionError(description)


def yazi_running():
    marker = f"--client-id\0{CLIENT}\0".encode()
    for cmdline in Path("/proc").glob("[0-9]*/cmdline"):
        try:
            if marker in cmdline.read_bytes():
                return True
        except OSError:
            pass
    return False


def tar_entry(archive, name, kind=tarfile.REGTYPE, link="", data=b"pwned\n"):
    info = tarfile.TarInfo(name)
    info.type, info.linkname, info.mode = kind, link, 0o644
    info.size = len(data) if kind == tarfile.REGTYPE else 0
    archive.addfile(info, io.BytesIO(data) if kind == tarfile.REGTYPE else None)


def craft(target, outside):
    """Archives whose entries try to leave the directory they are extracted into."""
    with zipfile.ZipFile(target / "traversal.zip", "w") as z:
        z.writestr("ok.txt", "ok\n")
        z.writestr("../../escape-traversal.txt", "pwned\n")
        z.writestr("..\\..\\escape-backslash.txt", "pwned\n")
    with zipfile.ZipFile(target / "absolute.zip", "w") as z:
        z.writestr("ok.txt", "ok\n")
        z.writestr(f"{outside}/escape-absolute.txt", "pwned\n")
    with zipfile.ZipFile(target / "symlink.zip", "w") as z:
        link = zipfile.ZipInfo("link")
        link.create_system, link.external_attr = 3, (stat.S_IFLNK | 0o777) << 16
        z.writestr(link, str(outside))
        z.writestr("link/escape-zip-link.txt", "pwned\n")
    tarball = io.BytesIO()
    with tarfile.open(fileobj=tarball, mode="w", format=tarfile.GNU_FORMAT) as t:
        tar_entry(t, "ok.txt", data=b"ok\n")
        tar_entry(t, f"{outside}/escape-tar-absolute.txt")
        tar_entry(t, "../../escape-tar-traversal.txt")
        tar_entry(t, "link", tarfile.SYMTYPE, str(outside))
        tar_entry(t, "link/escape-tar-link.txt")
        tar_entry(t, "up", tarfile.SYMTYPE, "../../../..")
        tar_entry(t, "up/escape-tar-relative.txt")
        tar_entry(t, "chain", tarfile.DIRTYPE)
        tar_entry(t, "chain/up", tarfile.SYMTYPE, "..")
        tar_entry(t, "chain/up2", tarfile.SYMTYPE, "up/..")
        tar_entry(t, "chain/up2/escape-tar-chain.txt")
        tar_entry(t, "hard", tarfile.LNKTYPE, f"{outside}/victim.txt")
    (target / "links.tar").write_bytes(tarball.getvalue())
    with gzip.open(target / "links.tar.gz", "wb") as compressed:
        compressed.write(tarball.getvalue())
    secret = target / "secret"
    secret.mkdir()
    (secret / "note.txt").write_text("secret\n")
    for name, extra in (("password.zip", ["-tzip"]), ("headers.7z", ["-t7z", "-mhe=on"])):
        subprocess.run([SEVENZIP, "a", *extra, "-pcorrect horse", "-bso0", "-bsp0", "--",
                        str(target / name), "note.txt"], cwd=secret, check=True)
    shutil.rmtree(secret)
    (target / "compressed.rar").write_bytes(RAR5)


def listing(archive):
    out = subprocess.run([SEVENZIP, "l", "-ba", "-slt", "--", str(archive)], check=True,
                         capture_output=True, text=True).stdout
    entries = {}
    for block in out.split("\n\n"):
        fields = dict(line.split(" = ", 1) for line in block.splitlines() if " = " in line)
        if "Path" in fields:
            entries[fields["Path"]] = fields
    return entries


with tempfile.TemporaryDirectory(prefix="seele-yazi-archives-") as temporary:
    root = Path(temporary)
    home, config, play, outside = root / "home", root / "config", root / "play", root / "outside"
    for directory in (home, root / "tmp", config / "plugins/pack.yazi", play / "w/inner",
                      play / "other", play / "x", outside):
        directory.mkdir(parents=True)
    (config / "plugins/pack.yazi/main.lua").write_text(PLUGIN)
    extract = f"{YA} pub extract --list %s"
    (config / "keymap.toml").write_text(
        '[[mgr.prepend_keymap]]\non = "C"\nrun = "plugin pack"\n\n'
        f"[[mgr.prepend_keymap]]\non = \"E\"\nrun = \"shell '{extract}'\"\n")
    (outside / "victim.txt").write_text("victim\n")

    w = play / "w"
    for name in ("-dash.txt", "@at.txt", "star*.txt", "q?.txt", "ünï cödé.txt", "inner/f.txt"):
        (w / name).write_text(name + "\n")
    (play / "other/g.txt").write_text("g\n")
    (w / "out-link").symlink_to(outside / "victim.txt")
    craft(play / "x", outside)

    env = {"HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"),
           "XDG_STATE_HOME": str(home / "state"), "XDG_CACHE_HOME": str(home / "cache"),
           "TMPDIR": str(root / "tmp"), "YAZI_CONFIG_HOME": str(config),
           "TERM": "xterm-256color", "LANG": "C.UTF-8",
           "PATH": os.pathsep.join([str(Path(SEVENZIP).parent), str(Path(YA).parent),
                                    str(Path(shutil.which("sh")).parent)])}
    socket = root / "tmux.sock"

    def tmux(*args):
        return subprocess.run([TMUX, "-S", str(socket), *args], check=True,
                              capture_output=True, text=True).stdout

    def screen():
        return tmux("capture-pane", "-p", "-t", "yazi")

    def emit(*args):
        subprocess.run([YA, "emit-to", CLIENT, *args], env=env, check=True, capture_output=True)

    def keys(*args, literal=False):
        tmux("send-keys", "-t", "yazi", *(["-l"] if literal else []), *args)
        time.sleep(0.3)

    def select(*paths):
        emit("escape", "--select")
        for path in paths:
            emit("reveal", str(path))
            wait_for(lambda: path.name in screen(), f"Yazi did not reveal {path}")
            emit("toggle", "--state=on")

    def hover(path):
        emit("escape", "--select")
        emit("reveal", str(path))
        wait_for(lambda: path.name in screen(), f"Yazi did not reveal {path}")
        time.sleep(0.3)

    def pack(name):
        keys("C")
        wait_for(lambda: "Pack into:" in screen(), "no name prompt")
        keys("C-u")
        keys(name, literal=True)
        keys("Enter")

    def finished(path):
        return lambda: path.exists() and path.stat().st_size > 0 and not any(
            p.name.startswith(".tmp_") for p in path.parent.iterdir())

    def visible(directory):
        return {p.name for p in directory.iterdir() if not p.name.startswith(".")}

    def escaped():
        found = [p for p in root.rglob("escape-*") if play / "x" not in p.parents]
        return found, (outside / "victim.txt").read_text()

    try:
        tmux("new-session", "-d", "-s", "yazi", "-x", "160", "-y", "45", "env", "-i",
             *[f"{key}={value}" for key, value in env.items()], YAZI, "--client-id", CLIENT, str(w))
        wait_for(lambda: "inner" in screen(), "Yazi did not start")
        time.sleep(1)

        # The hovered entry gives the default name; the archive is revealed.
        hover(w / "inner")
        keys("C")
        wait_for(lambda: "inner.zip" in screen(), "the default name is not the hovered entry")
        keys("Enter")
        wait_for(finished(w / "inner.zip"), "inner.zip was not created")
        assert set(listing(w / "inner.zip")) == {"inner", "inner/f.txt"}

        # Names that look like switches, list files or wildcards stay literal; links stay links.
        select(*(w / n for n in ("-dash.txt", "@at.txt", "star*.txt", "q?.txt", "ünï cödé.txt", "out-link")))
        pack("tricky.7z")
        wait_for(finished(w / "tricky.7z"), "tricky.7z was not created")
        entries = listing(w / "tricky.7z")
        assert set(entries) == {"-dash.txt", "@at.txt", "star*.txt", "q?.txt", "ünï cödé.txt",
                                "out-link"}, entries
        link = entries["out-link"]
        assert "l" in link["Attributes"] and link["Size"] == str(len(str(outside / "victim.txt"))), link

        # A selection across folders keeps paths relative to their closest common
        # folder, and the archive lands in the folder on screen.
        other = play / "other"
        select(w / "inner/f.txt", other / "g.txt")
        pack("across.tar.gz")
        wait_for(finished(other / "across.tar.gz"), "across.tar.gz was not created")
        assert set(listing(other / "across.tar.gz")) == {"across.tar"}
        tar = subprocess.run([SEVENZIP, "x", "-so", "--", str(other / "across.tar.gz")],
                             check=True, capture_output=True).stdout
        inner = subprocess.run([SEVENZIP, "l", "-ba", "-slt", "-ttar", "-si"], input=tar,
                               check=True, capture_output=True).stdout.decode()
        assert sorted(l[7:] for l in inner.splitlines() if l.startswith("Path = ")) == [
            "other/g.txt", "w/inner/f.txt"]

        # Packing a folder from inside it leaves the working directory out of the archive.
        select(w / "inner")
        emit("enter")
        time.sleep(0.5)
        pack("self.zip")
        wait_for(finished(w / "inner/self.zip"), "self.zip was not created")
        assert set(listing(w / "inner/self.zip")) == {"inner", "inner/f.txt"}
        emit("leave")

        # An existing name, an unknown extension and a path are refused without writing.
        before = (w / "inner.zip").read_bytes()
        hover(w / "q?.txt")
        pack("inner.zip")
        wait_for(lambda: "Already exists" in screen(), "an existing name was accepted")
        keys("C-u")
        keys("q.rar", literal=True)
        keys("Enter")
        wait_for(lambda: "Use .zip" in screen(), "an unsupported extension was accepted")
        keys("C-u")
        keys("inner/q.zip", literal=True)
        keys("Enter")
        wait_for(lambda: "not a path" in screen(), "a path was accepted")
        keys("Escape")
        keys("Escape")
        assert (w / "inner.zip").read_bytes() == before
        assert not (w / "q.rar").exists() and not (w / "inner/q.zip").exists()

        # 7-Zip failing leaves neither an archive nor a working directory.
        if os.geteuid() != 0:
            (w / "locked.txt").write_text("locked\n")
            (w / "locked.txt").chmod(0)
            select(w / "locked.txt")
            pack("locked.zip")
            wait_for(lambda: "Could not pack" in screen(), "a failed pack was not reported")
            time.sleep(1)
            assert not (w / "locked.zip").exists()
            assert not any(p.name.startswith(".tmp_") for p in w.iterdir())

        # Archives preview as their listing, RAR included.
        x = play / "x"
        emit("cd", str(x))
        for archive, member in (("traversal.zip", "ok.txt"), ("links.tar", "chain"),
                                ("compressed.rar", "test.bin")):
            hover(x / archive)
            wait_for(lambda: member in screen(), f"{archive} did not preview {member}")

        # Extraction: every entry stays inside the new folder, and the victim is untouched.
        for archive in ("traversal.zip", "absolute.zip", "symlink.zip", "links.tar", "links.tar.gz"):
            before = visible(x)
            hover(x / archive)
            keys("E")
            wait_for(lambda: visible(x) - before, f"{archive} was not extracted")
            time.sleep(1.5)
            assert escaped() == ([], "victim\n"), escaped()
            assert len(visible(x) - before) == 1, visible(x) - before
        assert (x / "traversal/ok.txt").read_text() == "ok\n"

        # RAR members decompress; an archive holding one entry yields just that entry.
        hover(x / "compressed.rar")
        keys("E")
        wait_for(lambda: (x / "test.bin").exists(), "compressed.rar was not extracted")
        time.sleep(1)
        assert (x / "test.bin").stat().st_size == 1200, "RAR member extracted empty"

        # Password-protected archives ask, ask again after a wrong answer, then extract.
        for archive in ("password.zip", "headers.7z"):
            before = visible(x)
            hover(x / archive)
            keys("E")
            wait_for(lambda: "Password for" in screen(), f"{archive} did not ask for a password")
            keys("wrong", literal=True)
            keys("Enter")
            time.sleep(1)
            wait_for(lambda: "Password for" in screen(), f"{archive} accepted a wrong password")
            keys("correct horse", literal=True)
            keys("Enter")
            wait_for(lambda: visible(x) - before, f"{archive} was not extracted")
            time.sleep(1)
            (created,) = visible(x) - before
            assert (x / created).read_text() == "secret\n", created
        print("Yazi archives: pack names, links, folders, refusals, failure; "
              "preview zip, tar, rar; extract traversal, absolute, links, rar, passwords passed")
    finally:
        subprocess.run([TMUX, "-S", str(socket), "kill-server"], capture_output=True)
        # Yazi writes its state as it exits; let it finish before the directory goes.
        wait_for(lambda: not yazi_running(), "Yazi did not exit", 10)
