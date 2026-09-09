#!/usr/bin/env python3
"""Attach Seele's failure reporter to installed system services."""

from __future__ import annotations

import os
from pathlib import Path
import stat
import sys


DEFAULT_UNIT_PATHS = (
    "/etc/systemd/system",
    "/run/systemd/system",
    "/run/current-system/systemd/lib/systemd/system",
    "/usr/local/lib/systemd/system",
    "/usr/lib/systemd/system",
    "/lib/systemd/system",
)
DROP_IN = "[Unit]\nOnFailure=seele-failure-report@%n.service\n"


def source_directories() -> list[Path]:
    override = os.environ.get("SEELE_FAILURE_UNIT_PATH")
    values = override.split(os.pathsep) if override is not None else DEFAULT_UNIT_PATHS
    return [Path(value) for value in values if value]


def is_masked(path: Path) -> bool:
    try:
        return path.is_symlink() and path.resolve(strict=False) == Path("/dev/null")
    except OSError:
        return False


def service_names() -> list[str]:
    names: set[str] = set()
    seen: set[str] = set()
    for directory in source_directories():
        try:
            entries = sorted(directory.iterdir(), key=lambda entry: entry.name)
        except OSError:
            continue
        for entry in entries:
            name = entry.name
            if name in seen or not name.endswith(".service"):
                continue
            seen.add(name)
            if name.startswith("seele-failure-") or is_masked(entry):
                continue
            try:
                metadata = entry.lstat()
            except OSError:
                continue
            if stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
                names.add(name)
    return sorted(names)


def write_drop_ins(output: Path) -> None:
    for name in service_names():
        directory = output / f"{name}.d"
        directory.mkdir(mode=0o755, parents=True, exist_ok=True)
        (directory / "50-seele-failure-report.conf").write_text(DROP_IN, encoding="utf-8")


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print("usage: seele-failure-generator NORMAL EARLY LATE", file=sys.stderr)
        return 2
    write_drop_ins(Path(argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
