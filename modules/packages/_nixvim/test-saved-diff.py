#!/usr/bin/env python3
"""Run real Neovim comparisons in a disposable HOME, without user configuration."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile

editor = os.environ.get("NVIM") or shutil.which("nvim")
if not editor:
    raise SystemExit("Set NVIM to a Neovim executable")
source = Path(__file__).with_name("saved-diff.lua").resolve()
with tempfile.TemporaryDirectory(prefix="seele-saved-diff-test-") as directory:
    root = Path(directory)
    env = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
               XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"),
               XDG_CACHE_HOME=str(root / "cache"), TEST_ROOT=str(root), DIFF_SOURCE=str(source))
    os.mkfifo(root / "fifo")
    script = root / "test.lua"
    script.write_text(r'''
local api = vim.api
local root = vim.env.TEST_ROOT
local messages = {}
vim.notify = function(message) messages[#messages + 1] = message end
dofile(vim.env.DIFF_SOURCE)
local function eq(a, b, message) assert(vim.deep_equal(a, b), (message or '') .. '\n' .. vim.inspect({a, b})) end
local function write(path, bytes)
  local f = assert(io.open(path, 'wb')); f:write(bytes); f:close()
end
local function read(path)
  local f = assert(io.open(path, 'rb')); local bytes = f:read('*a'); f:close(); return bytes
end
local function edit(path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end
local function settle() vim.wait(20, function() return false end) end
local function count()
  local n = 0
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(b) and api.nvim_buf_get_name(b):match('saved%-diff://') then n = n + 1 end
  end
  return n
end
local function failed(pattern)
  local tabs, bufs = #api.nvim_list_tabpages(), count()
  local n = #messages
  vim.cmd.SavedDiff()
  eq(#messages, n + 1)
  assert(messages[#messages]:find(pattern), messages[#messages])
  eq(#api.nvim_list_tabpages(), tabs); eq(count(), bufs)
end
failed('named, ordinary')
local path = root .. '/space | quote\' $HOME % #.txt'
local disk = 'first\nsecond\nthird\n'
write(path, disk); edit(path)
local original, origin = api.nvim_get_current_buf(), api.nvim_get_current_win()
vim.cmd('normal! ggA edited')
vim.cmd('normal! j0')
vim.wo.foldmethod = 'manual'
vim.wo.scrollbind = false
vim.wo.cursorbind = false
vim.wo.wrap = true
vim.o.autochdir = true
local function history() local tree = vim.fn.undotree(); tree.synced = nil; return tree end
local undo, view, cwd = history(), vim.fn.winsaveview(), vim.fn.getcwd()
local changed = api.nvim_buf_get_lines(original, 0, -1, false)
local function preserved()
  eq(api.nvim_buf_get_lines(original, 0, -1, false), changed)
  eq(vim.bo[original].modified, true); eq(read(path), disk)
  eq(api.nvim_get_current_win(), origin)
  eq(vim.fn.winsaveview(), view, 'original view')
  eq(history(), undo, 'undo state')
  eq(vim.wo.foldmethod, 'manual'); eq(vim.wo.diff, false)
  eq(vim.wo.scrollbind, false); eq(vim.wo.cursorbind, false); eq(vim.wo.wrap, true)
  eq(vim.fn.getcwd(), cwd); eq(count(), 0)
end
-- No file-read/FileType/buffer events should run while constructing snapshots.
local events = 0
local group = api.nvim_create_augroup('Fixture', {})
api.nvim_create_autocmd({'BufReadPre', 'BufReadPost', 'BufNew', 'BufEnter', 'FileType'}, {
  group = group, callback = function() events = events + 1 end,
})
vim.o.autochdir = true
vim.cmd.SavedDiff()
eq(events, 0); eq(vim.o.autochdir, true); eq(vim.o.eventignore, '')
api.nvim_del_augroup_by_id(group)
eq(count(), 2); eq(#api.nvim_list_tabpages(), 2)
local windows = api.nvim_tabpage_list_wins(0)
eq(#windows, 2)
for _, win in ipairs(windows) do eq(vim.wo[win].diff, true) end
local left, right = api.nvim_win_get_buf(windows[1]), api.nvim_win_get_buf(windows[2])
eq(api.nvim_buf_get_lines(left, 0, -1, false), {'first', 'second', 'third'})
eq(api.nvim_buf_get_lines(right, 0, -1, false), changed)
for _, buf in ipairs({left, right}) do
  eq(vim.bo[buf].modifiable, false); eq(vim.bo[buf].readonly, true)
  eq(vim.bo[buf].buftype, 'nofile'); eq(vim.bo[buf].buflisted, false)
  eq(vim.bo[buf].swapfile, false); eq(vim.bo[buf].undofile, false)
  eq(vim.bo[buf].modeline, false)
  assert(not pcall(api.nvim_buf_set_lines, buf, 0, -1, false, {'bad'}))
end
vim.cmd.SavedDiff(); preserved()
-- Reopening rereads the saved bytes; repeated invocation accumulates nothing.
for _ = 1, 4 do vim.cmd.SavedDiff(); vim.cmd.SavedDiffClose(); preserved() end
for _, command in ipairs({'q', 'tabclose', 'bwipeout!'}) do
  vim.cmd.SavedDiff(); vim.cmd(command); settle(); preserved()
end
vim.cmd.SavedDiff()
local mapping = vim.fn.maparg('q', 'n', false, true)
mapping.callback(); preserved()
vim.cmd.SavedDiff()
vim.fn.maparg('<Esc>', 'n', false, true).callback(); preserved()
-- Existing diff panes and manual fold state are outside the comparison tab.
vim.cmd('vsplit'); vim.cmd('diffthis'); local peer = api.nvim_get_current_win()
api.nvim_set_current_win(origin); vim.cmd('diffthis')
local diffview = vim.fn.winsaveview()
vim.cmd.SavedDiff(); vim.cmd.SavedDiffClose()
eq(vim.wo.diff, true); eq(vim.wo[peer].diff, true); eq(vim.fn.winsaveview(), diffview)
vim.cmd('diffoff!'); api.nvim_win_close(peer, true)
-- Undo still edits only the source; no comparison action wrote the file.
vim.cmd('undo'); eq(api.nvim_buf_get_lines(original, 0, -1, false), {'first', 'second', 'third'})
eq(read(path), disk)
-- Missing, special, binary and bounded-size failures leave no UI artifacts.
vim.cmd('enew!'); api.nvim_buf_set_name(0, root .. '/missing.txt'); failed('Cannot read saved file')
vim.bo.buftype = 'nofile'; failed('named, ordinary'); vim.bo.buftype = ''
local huge = root .. '/large.txt'; write(huge, string.rep('x', 2 * 1024 * 1024 + 1))
api.nvim_buf_set_name(0, huge); failed('Saved file exceeds')
api.nvim_buf_set_lines(0, 0, -1, false, {string.rep('x', 2 * 1024 * 1024 + 1)})
failed('Current buffer exceeds')
local boundary = root .. '/line-boundary.txt'; write(boundary, string.rep('x\n', 20000))
vim.cmd('enew!'); api.nvim_buf_set_name(0, boundary); vim.cmd.SavedDiff()
eq(count(), 2); vim.cmd.SavedDiffClose()
local many = root .. '/many-lines.txt'; write(many, string.rep('x\n', 20001))
vim.cmd('enew!'); api.nvim_buf_set_name(0, many); failed('Saved file exceeds the 20000 line')
local few = root .. '/few.txt'; write(few, 'x\n'); vim.cmd('enew!'); api.nvim_buf_set_name(0, few)
local lines = {}; for i = 1, 20001 do lines[i] = 'x' end
api.nvim_buf_set_lines(0, 0, -1, false, lines); failed('Current buffer exceeds the 20000 line')
vim.cmd('enew!'); api.nvim_buf_set_name(0, root); failed('not a regular file')
local unreadable = root .. '/unreadable.txt'; write(unreadable, 'secret')
assert(vim.uv.fs_chmod(unreadable, 0)); api.nvim_buf_set_name(0, unreadable)
failed('Cannot read saved file'); assert(vim.uv.fs_chmod(unreadable, 384))
local fifo = root .. '/fifo'; api.nvim_buf_set_name(0, fifo); failed('not a regular file')
local binary = root .. '/binary'; write(binary, 'a\0b'); api.nvim_buf_set_name(0, binary)
failed('Binary saved files'); vim.bo.binary = true; failed('Binary buffers'); vim.bo.binary = false
-- Read modeline-looking text without evaluating it, including external disk edits.
write(path, 'vim: set tabstop=19 :\r\nlast'); edit(path)
vim.bo.tabstop = 7
write(path, 'vim: set tabstop=29 :\r\nexternal')
vim.cmd.SavedDiff(); eq(vim.bo[api.nvim_win_get_buf(origin)].tabstop, 7)
local savedwin = api.nvim_tabpage_list_wins(0)[1]
local saved = api.nvim_win_get_buf(savedwin)
eq(api.nvim_buf_get_lines(saved, 0, -1, false), {'vim: set tabstop=29 :', 'external'})
eq(vim.bo[saved].endofline, false); eq(vim.bo[saved].fileformat, 'dos')
assert(vim.wo[savedwin].winbar:find('no final newline'))
vim.cmd.SavedDiffClose()
for _, bytes in ipairs({'', 'one', 'one\n', '\n', '\239\187\191hello\n'}) do
  write(path, bytes); vim.cmd.SavedDiff(); eq(count(), 2); vim.cmd.SavedDiffClose()
  eq(read(path), bytes)
end
-- Decode a non-UTF-8 file using the source buffer's actual encoding.
write(path, 'caf\233\n'); vim.bo.fileencoding = 'latin1'
vim.cmd.SavedDiff()
local latin = api.nvim_win_get_buf(api.nvim_tabpage_list_wins(0)[1])
eq(api.nvim_buf_get_lines(latin, 0, -1, false), {'caf\195\169'})
vim.cmd.SavedDiffClose(); vim.bo.fileencoding = 'utf-8'; vim.bo.modified = false
-- A replaced pane survives cleanup, and closing the original tab is harmless.
vim.cmd.SavedDiff()
vim.cmd('enew')
settle(); eq(count(), 0)
for _, win in ipairs(api.nvim_list_wins()) do eq(vim.wo[win].diff, false); eq(vim.wo[win].winbar, '') end
vim.cmd('tabonly')
edit(path); vim.cmd.SavedDiff()
vim.cmd('tabprevious'); vim.cmd('tabclose'); settle()
eq(count(), 0); eq(#api.nvim_list_tabpages(), 1)
eq(vim.wo.diff, false); eq(vim.wo.winbar, '')
print('SavedDiff: lifecycle, isolation, read-only snapshots, undo, views, bytes, formats and errors passed')
vim.cmd('qa!')
''')
    result = subprocess.run([editor, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                             "-l", str(script)], env=env, capture_output=True, text=True, timeout=30)
    print(result.stdout + result.stderr, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
