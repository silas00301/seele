"""Refresh only the portable configuration links owned by Seele."""

import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile


def links_in(source):
    links = {}
    if source.is_dir():
        for directory, dirs, files in os.walk(source, followlinks=True):
            for name in files:
                path = Path(directory, name)
                links[str(path.relative_to(source))] = str(path)
    return links


def legacy_links(source):
    links = {}
    if source.is_dir():
        for directory, dirs, files in os.walk(source):
            for name in dirs + files:
                path = Path(directory, name)
                if path.is_symlink():
                    links[str(path.relative_to(source))] = os.readlink(path)
                elif path.is_file():
                    links[str(path.relative_to(source))] = str(path)
    return links


def read_json(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def atomic_json(path, value):
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".seele-manifest-")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def materialize(source, destination):
    source = Path(source)
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Keep the lock outside the tree we manage, and hold it across both the
    # generation check and refresh so concurrent first launches cannot race.
    with (destination.parent / ("." + destination.name + ".lock")).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        destination.mkdir(parents=True, exist_ok=True)
        manifest = destination / ".seele-manifest.json"
        previous = read_json(manifest)
        if previous.get("generation") == str(source):
            return
        owned = previous.get("links", {})
        if not isinstance(owned, dict):
            owned = {}
        if not previous:
            try:
                generation = (destination / ".seele-generation").read_text().strip()
                if generation.startswith("/nix/store/"):
                    owned = legacy_links(Path(generation) / ".config")
            except OSError:
                pass
        wanted = links_in(source)
        # Delete only links whose literal target still matches our manifest.
        # An application replacing a link with a regular file or its own link
        # takes ownership of that path, and subsequent generations preserve it.
        for name, target in owned.items():
            relative = Path(name)
            if relative.is_absolute() or ".." in relative.parts:
                continue
            path = destination / relative
            if any(parent.is_symlink() for parent in path.parents if parent != destination and destination in parent.parents):
                continue
            if path.is_symlink() and os.readlink(path) == target:
                path.unlink()
        installed = {}
        for name, target in wanted.items():
            path = destination / name
            parent = destination
            blocked = False
            for part in Path(name).parts[:-1]:
                parent /= part
                if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                    blocked = True
                    break
                parent.mkdir(exist_ok=True)
            if blocked:
                continue
            if not path.exists() and not path.is_symlink():
                path.symlink_to(target)
                installed[name] = target
            elif path.is_symlink() and os.readlink(path) == target:
                # Recover links already installed by an interrupted refresh.
                installed[name] = target
        atomic_json(manifest, {"generation": str(source), "links": installed})


if __name__ == "__main__":
    materialize(*sys.argv[1:])
