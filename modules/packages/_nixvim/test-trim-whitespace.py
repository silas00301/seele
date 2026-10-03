#!/usr/bin/env python3
"""Exercise whitespace cleanup in an isolated real Neovim, without plugins."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

editor = os.environ.get("NVIM") or shutil.which("nvim")
if not editor:
    raise SystemExit("Neovim is required (set NVIM or PATH)")

with tempfile.TemporaryDirectory(prefix="seele-trim-whitespace-") as temporary:
    root = Path(temporary)
    source = root / "source.txt"
    source.write_text("saved content  \n")
    script = root / "test.lua"
    script.write_text(r'''
local function eq(a, b)
  assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b))
end
local messages = {}
vim.notify = function(message, level) messages[#messages + 1] = {message, level} end
vim.g.mapleader = " "
dofile(vim.env.TEST_MODULE).setup()
vim.cmd.edit(vim.env.TEST_SOURCE)
local function reset(lines, filetype)
  vim.bo.readonly, vim.bo.modifiable, vim.bo.buftype = false, true, ""
  vim.bo.filetype = filetype or "text"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  -- Separate fixture setup from the edit under test in this Lua invocation.
  vim.cmd('let &undolevels = &undolevels')
  vim.bo.modified = false
end
local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function keys(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
end
local original = {"one \t", "  two", "三  ", "\t \t", "last\194\160"}
reset(original)
vim.api.nvim_win_set_cursor(0, {2, 2})
vim.fn.setreg('a', 'previous unnamed', 'v')
vim.fn.setreg('"', {points_to = 'a'})
vim.fn.setreg('0', 'previous yank', 'v')
vim.fn.setreg('/', 'previous search', 'v')
local function registers()
  return {vim.fn.getreginfo('"'), vim.fn.getreginfo('a'), vim.fn.getreginfo('0'), vim.fn.getreginfo('/')}
end
local saved_registers, view = registers(), vim.fn.winsaveview()
local namespace = vim.api.nvim_create_namespace('trim-test')
local mark = vim.api.nvim_buf_set_extmark(0, namespace, 2, 0, {})
keys(' cw')
eq(lines(), {"one", "  two", "三", "", "last\194\160"})
eq(registers(), saved_registers)
eq(vim.fn.winsaveview(), view)
eq(vim.api.nvim_buf_get_extmark_by_id(0, namespace, mark, {}), {2, 0})
assert(vim.bo.modified)
vim.cmd.undo()
eq(lines(), original)
vim.cmd.redo()
eq(lines(), {"one", "  two", "三", "", "last\194\160"})
-- A clean buffer does not acquire an edit or undo entry.
reset({"clean", ""})
local tick, undo = vim.api.nvim_buf_get_changedtick(0), vim.fn.undotree()
vim.cmd.TrimWhitespace()
eq(tick, vim.api.nvim_buf_get_changedtick(0))
eq(undo, vim.fn.undotree())
assert(not vim.bo.modified)
-- Explicit range and forward/reverse linewise, characterwise and blockwise
-- mappings all apply to complete selected lines; surrounding lines stay intact.
local ranged = {"outside  ", "middle  ", "selected\t", "outside\t"}
reset(ranged)
vim.cmd('2,3TrimWhitespace')
eq(lines(), {"outside  ", "middle", "selected", "outside\t"})
for _, selection in ipairs({'2GVj', '3GVk', '2Gvj', '2G<C-v>j'}) do
  reset(ranged)
  keys(selection .. ' cw')
  eq(lines(), {"outside  ", "middle", "selected", "outside\t"})
  vim.cmd.undo()
  eq(lines(), ranged)
end
-- Markdown/MDX hard breaks survive; whitespace-only lines and single spaces go.
for _, filetype in ipairs({'markdown', 'markdown.pandoc', 'mdx'}) do
  reset({"hard  ", "harder   ", "ordinary ", "tab\t", "   ", "\\  "}, filetype)
  vim.cmd.TrimWhitespace()
  eq(lines(), {"hard  ", "harder   ", "ordinary", "tab", "", "\\  "})
  assert(messages[#messages][1]:find('kept 3 Markdown hard break', 1, true))
  vim.cmd('1,2TrimWhitespace!')
  eq(lines(), {"hard", "harder", "ordinary", "tab", "", "\\  "})
end
-- Read-only, special and unmodifiable buffers refuse even with bang.
for _, option in ipairs({'readonly', 'modifiable', 'buftype'}) do
  reset({"unchanged  "})
  vim.bo[option] = option == 'buftype' and 'nofile' or option == 'readonly'
  local before = vim.api.nvim_buf_get_changedtick(0)
  vim.cmd('TrimWhitespace!')
  eq(lines(), {"unchanged  "})
  eq(before, vim.api.nvim_buf_get_changedtick(0))
  eq(messages[#messages][2], vim.log.levels.WARN)
end
-- No implicit save, hooks or filesystem operation belongs to this command.
vim.cmd('qa!')
''')
    env = dict(os.environ, HOME=str(root / "home"), XDG_CONFIG_HOME=str(root / "config"),
               XDG_STATE_HOME=str(root / "state"), XDG_DATA_HOME=str(root / "data"),
               XDG_CACHE_HOME=str(root / "cache"), TEST_SOURCE=str(source),
               TEST_MODULE=str(Path(__file__).with_name("trim-whitespace.lua").resolve()))
    result = subprocess.run([editor, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", str(script)],
                            cwd=root, env=env, text=True, capture_output=True, timeout=20)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    assert source.read_text() == "saved content  \n", "Cleanup wrote the source file"
print("Whitespace cleanup: real mappings, ranges, undo, state, Markdown and refusal checks passed")
