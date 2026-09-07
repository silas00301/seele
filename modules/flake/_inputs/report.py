"""Inspect version-7 flake lock graphs without fetching or evaluating inputs."""

import argparse
from collections import deque
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit, urlunsplit


class LockError(ValueError):
    pass


def terminal_text(value):
    return "".join(c if c.isprintable() else json.dumps(c)[1:-1] for c in str(value))


def safe_url(value):
    """Discard URL credentials and request-specific query/fragment data."""
    try:
        parsed = urlsplit(value)
        if parsed.netloc:
            host = parsed.hostname
            if not host:
                return "[URL omitted]"
            if ":" in host:
                host = f"[{host}]"
            if parsed.port is not None:
                host += f":{parsed.port}"
            return urlunsplit((parsed.scheme, host, parsed.path, "", ""))
        if parsed.scheme == "file":
            return urlunsplit(("file", "", parsed.path, "", ""))
        # Git also accepts scp-style user@host:path references.
        match = re.fullmatch(r"(?:[^/@]+@)?([^/:?#]+):([^?#]+)(?:[?#].*)?", value)
        if match and "://" not in value:
            return f"{match[1]}:{match[2]}"
    except ValueError:
        pass
    return "[URL omitted]"


def modified_date(locked):
    timestamp = locked.get("lastModified")
    if timestamp is None:
        return None
    if type(timestamp) is not int or timestamp < 0:
        raise LockError("lastModified must be a nonnegative integer")
    try:
        return datetime.fromtimestamp(timestamp, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except (OverflowError, OSError, ValueError):
        raise LockError("lastModified is outside the supported date range") from None


def source_label(locked):
    kind = locked["type"]
    if "url" in locked:
        return safe_url(locked["url"])
    if kind == "path":
        return "path:" + locked.get("path", "[unspecified]")
    if kind in ("github", "gitlab", "sourcehut"):
        repository = "/".join([locked.get("owner", "?"), locked.get("repo", "?")])
        if "host" in locked:
            host = safe_url("https://" + locked["host"])
            repository = host.removeprefix("https://").rstrip("/") + "/" + repository
        return f"{kind}:{repository}"
    return kind


class LockGraph:
    def __init__(self, data):
        if not isinstance(data, dict) or type(data.get("version")) is not int or data["version"] != 7:
            raise LockError("expected a version-7 flake.lock object")
        self.nodes = data.get("nodes")
        self.root = data.get("root")
        if not isinstance(self.nodes, dict) or not isinstance(self.root, str) or self.root not in self.nodes:
            raise LockError("lock file needs a nodes object and an existing root node")
        self.resolved = {}
        for name, node in self.nodes.items():
            if not isinstance(name, str) or not name or not isinstance(node, dict):
                raise LockError("each node must have a nonempty name and an object value")
            inputs = node.get("inputs", {})
            if not isinstance(inputs, dict):
                raise LockError(f"inputs of node {terminal_text(name)} must be an object")
            for key, ref in inputs.items():
                if not isinstance(key, str) or not key or "/" in key:
                    raise LockError("input names must be nonempty strings without slashes")
                if isinstance(ref, str):
                    if ref not in self.nodes:
                        raise LockError(f"input {terminal_text(key)} references a missing node")
                elif not isinstance(ref, list) or any(not isinstance(p, str) or not p or "/" in p for p in ref):
                    raise LockError(f"input {terminal_text(key)} needs a node name or follows path")
            locked = node.get("locked")
            if name == self.root and locked is None:
                continue
            if not isinstance(locked, dict) or not isinstance(locked.get("type"), str) or not locked["type"]:
                raise LockError(f"node {terminal_text(name)} needs locked source metadata")
            for key in ("url", "path", "owner", "repo", "host", "rev"):
                if key in locked and not isinstance(locked[key], str):
                    raise LockError(f"locked {key} must be a string")
            modified_date(locked)

    def inputs(self, node):
        return self.nodes[node].get("inputs", {})

    def resolve(self, path):
        """Resolve root-relative paths with an explicit stack and cached follows."""
        # A frame stores its current node, remaining path, and the follows edge
        # whose result it will cache. No Python recursion or path expansion.
        frames = [[self.root, iter(path), None]]
        active = set()
        while frames:
            frame = frames[-1]
            part = next(frame[1], None)
            if part is None:
                result = frame[0]
                _, _, edge = frames.pop()
                if edge is not None:
                    self.resolved[edge] = result
                    active.remove(edge)
                if not frames:
                    return result
                frames[-1][0] = result
                continue
            edge = (frame[0], part)
            if part not in self.inputs(frame[0]):
                raise LockError(f"missing input {terminal_text(part)} on node {terminal_text(frame[0])}")
            ref = self.inputs(frame[0])[part]
            if isinstance(ref, str):
                frame[0] = ref
            elif edge in self.resolved:
                frame[0] = self.resolved[edge]
            elif edge in active:
                raise LockError(f"cyclic follows at {terminal_text(frame[0])}/{terminal_text(part)}")
            else:
                active.add(edge)
                frames.append([self.root, iter(ref), edge])
        raise LockError("could not resolve input")

    def row(self, path):
        node = self.resolve(path)
        parent = self.resolve(path[:-1])
        ref = self.inputs(parent)[path[-1]]
        locked = self.nodes[node].get("locked", {"type": "root"})
        return {
            "input": "/".join(path),
            "node": node,
            "type": locked["type"],
            "source": source_label(locked),
            "revision": locked.get("rev"),
            "last_modified": modified_date(locked),
            "follows": "/".join(ref) if isinstance(ref, list) else None,
            "shared_with": None,
            "cycle": False,
        }

    def report(self, include_all=False, selected=None):
        if selected is not None:
            path = tuple(selected.split("/"))
            if not selected or any(not p for p in path):
                raise LockError("INPUT must be a slash-separated input path")
            initial = [path]
        else:
            initial = [(name,) for name in sorted(self.inputs(self.root))]
        queue = deque((path, frozenset([self.root])) for path in initial)
        expanded = {self.root: "<root>"}
        rows = []
        edges = {}
        while queue:
            path, ancestors = queue.popleft()
            row = self.row(path)
            node = row["node"]
            row["cycle"] = node in ancestors
            if node in expanded:
                row["shared_with"] = expanded[node]
            rows.append(row)
            parent = self.resolve(path[:-1])
            edges.setdefault(parent, set()).add(node)
            if not include_all or node in expanded:
                continue
            expanded[node] = row["input"]
            queue.extend((path + (name,), ancestors | {node}) for name in sorted(self.inputs(node)))
        # Shared nodes can close a cycle through another root input, so path
        # ancestors alone are insufficient. Mark DFS back-edges explicitly.
        colors = {}
        cycle_edges = set()
        for start in sorted(edges):
            if start in colors:
                continue
            colors[start] = 1
            stack = [(start, iter(sorted(edges.get(start, ()))))]
            while stack:
                parent, children = stack[-1]
                child = next(children, None)
                if child is None:
                    colors[parent] = 2
                    stack.pop()
                elif colors.get(child) == 1:
                    cycle_edges.add((parent, child))
                elif child not in colors:
                    colors[child] = 1
                    stack.append((child, iter(sorted(edges.get(child, ())))))
        for row in rows:
            parent = self.resolve(row["input"].split("/")[:-1])
            row["cycle"] = row["cycle"] or (parent, row["node"]) in cycle_edges
        return sorted(rows, key=lambda row: row["input"])


def render(rows):
    if not rows:
        return "No inputs."
    lines = ["INPUT\tNODE\tTYPE\tSOURCE\tREVISION\tMODIFIED UTC\tFOLLOWS / SHARED"]
    for row in rows:
        notes = []
        if row["follows"] is not None:
            notes.append("follows " + (row["follows"] or "<root>"))
        if row["shared_with"]:
            notes.append(("cycle to " if row["cycle"] else "shared with ") + row["shared_with"])
        values = [row["input"], row["node"], row["type"], row["source"], (row["revision"] or "")[:12] or "—",
                  row["last_modified"] or "—", "; ".join(notes) or "—"]
        lines.append("\t".join(terminal_text(value) for value in values))
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="seele-inputs", description=__doc__)
    parser.add_argument("--lock-file", type=Path, default=Path("flake.lock"), help="lock file to read (default: ./flake.lock)")
    parser.add_argument("--all", action="store_true", help="include transitive edges, expanding each shared node once")
    parser.add_argument("--json", action="store_true", help="write structured rows as JSON")
    parser.add_argument("input", nargs="?", metavar="INPUT", help="exact root-relative input path; with --all, include its subtree")
    args = parser.parse_args(argv)
    try:
        with args.lock_file.open(encoding="utf-8") as stream:
            graph = LockGraph(json.load(stream))
        rows = graph.report(args.all, args.input)
    except (OSError, UnicodeError, ValueError, RecursionError) as error:
        parser.error(terminal_text(error))
    print(json.dumps(rows, indent=2, ensure_ascii=True) if args.json else render(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
