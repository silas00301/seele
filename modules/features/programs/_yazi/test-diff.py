#!/usr/bin/env python3
"""Run packaged diff plugin result handling with real diff and a Yazi API fixture."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

plugin = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="seele-yazi-diff-") as temp:
    root = Path(temp)
    a, b = root / "one", root / "two"
    a.write_text("same\n")
    b.write_text("same\n")
    cases = []

    def capture(expected, copied=False):
        result = subprocess.run(["diff", "-Naur", str(a), str(b)], capture_output=True, text=True)
        cases.append({"output": {"status": {"code": result.returncode}, "stdout": result.stdout,
                                  "stderr": result.stderr}, "expected": expected, "copied": copied})
        return result.returncode

    assert capture("No differences found") == 0
    b.write_text("different\n")
    assert capture("Diff copied to clipboard", True) == 1
    b.chmod(0)
    try:
        assert capture("Diff failed", False) == 2, "Run as an ordinary user for permission denial"
    finally:
        b.chmod(0o600)
    cases.extend([
        {"output": {"status": {"code": 2}, "stdout": "partial patch", "stderr": "failure\n" * 200}, "expected": "Diff failed"},
        {"output": {"status": {}, "stdout": "partial patch", "stderr": "terminated"}, "expected": "Diff failed"},
        {"expected": "Failed to run diff"},
    ])
    (root / "cases.json").write_text(json.dumps(cases))
    script = root / "check.lua"
    script.write_text('''
local cases = vim.json.decode(table.concat(vim.fn.readfile(vim.env.CASES), "\\n"))
for _, case in ipairs(cases) do
  local clipboard, notice = "previous clipboard", nil
  ya = {
    sync = function(fn) return fn end,
    notify = function(value) notice = value end,
    clipboard = function(value) clipboard = value end,
  }
  cx = { active = { selected = { setmetatable({}, { __tostring = function() return "one" end }) }, current = { hovered = { path = "two" } } } }
  Command = function(name)
    assert(name == "diff")
    return { arg = function(self) return self end, output = function() return case.output, "launch failed" end }
  end
  dofile(vim.env.DIFF_PLUGIN).entry()
  assert(notice and notice.content:find(case.expected, 1, true), vim.inspect(notice))
  if case.copied then
    assert(clipboard == case.output.stdout)
  else
    assert(clipboard == "previous clipboard", "error overwrote clipboard")
  end
  if case.expected:find("failed") or case.expected:find("Failed") then
    assert(notice.level == "error")
    assert(#notice.content < 600 and not notice.content:find("[%c]"))
  end
end
print("Yazi diff: identical, different, unreadable, partial, signal, launch passed")
vim.cmd("qa!")
''')
    env = {**os.environ, "HOME": temp, "XDG_CONFIG_HOME": temp, "XDG_STATE_HOME": temp,
           "XDG_DATA_HOME": temp, "CASES": str(root / "cases.json"), "DIFF_PLUGIN": plugin}
    subprocess.run([os.environ.get("NVIM", "nvim"), "--headless", "-u", "NONE", "-i", "NONE", "-l", str(script)], env=env, check=True, timeout=20)
