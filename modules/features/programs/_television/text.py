"""Bridge ripgrep's JSON records to Television without shell-interpolating paths."""

import base64
import json
import os
import re
import subprocess
import sys


def field_bytes(field):
    if "text" in field:
        return field["text"].encode("utf-8")
    return base64.b64decode(field["bytes"], validate=True)


def display_text(value):
    # Keep one record per line, including for paths containing newlines or tabs,
    # and prevent file contents from injecting terminal control sequences.
    return "".join(char if char.isprintable() else json.dumps(char)[1:-1] for char in value)


def entry(event):
    if event["type"] != "match":
        return None
    data = event["data"]
    path = field_bytes(data["path"])
    line = data["line_number"]
    token = base64.urlsafe_b64encode(path).decode("ascii")
    contents = field_bytes(data["lines"]).decode("utf-8", errors="replace").rstrip("\r\n")
    label = f"{display_text(os.fsdecode(path))}:{line}: {display_text(contents)}"
    return f"{token}\t{line}\t{label}"


def source(hidden=False):
    command = [
        "rg", "--json", "--line-number", "--no-config", "--color=never",
        "--glob=!.git", "--glob=!.jj",
    ]
    if hidden:
        command.append("--hidden")
    command.extend(["--", ".", "."])
    with subprocess.Popen(command, stdout=subprocess.PIPE) as process:
        try:
            for record in process.stdout:
                result = entry(json.loads(record))
                if result is not None:
                    print(result, flush=True)
        except BrokenPipeError:
            process.terminate()
            # Avoid another flush into the closed pipe during Python shutdown.
            with open(os.devnull, "w") as null:
                os.dup2(null.fileno(), sys.stdout.fileno())
        status = process.wait()
    return 0 if status in (0, 1, -15) else status


def location(token, line):
    if not re.fullmatch(r"[A-Za-z0-9_=-]+", token):
        raise ValueError("invalid file token")
    path = os.fsdecode(base64.b64decode(token, altchars=b"-_", validate=True))
    if not path or "\0" in path or not re.fullmatch(r"[1-9][0-9]*", line):
        raise ValueError("invalid file location")
    return path, line


def main(args):
    if args == ["source"] or args == ["source", "--hidden"]:
        return source(hidden=len(args) == 2)
    if len(args) != 3 or args[0] not in ("preview", "edit"):
        raise ValueError("usage: seele-project-text source [--hidden] | preview|edit TOKEN LINE")
    path, line = location(args[1], args[2])
    if args[0] == "preview":
        return subprocess.call([
            "bat", "--paging=never", "--style=numbers", "--color=always",
            "--highlight-line", line, "--", path,
        ])
    os.execvp("nvim", ["nvim", f"+{line}", "--", path])


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError) as error:
        print(f"seele-project-text: {error}", file=sys.stderr)
        sys.exit(2)
