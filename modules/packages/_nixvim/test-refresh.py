#!/usr/bin/env python3
"""Exercise external-file refresh in real Neovim with disposable private state."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

editor = os.environ.get("NVIM") or shutil.which("nvim")
if not editor:
    raise SystemExit("Set NVIM to an existing Neovim executable")
source = Path(__file__).with_name("refresh.lua").resolve()
with tempfile.TemporaryDirectory(prefix="seele-refresh-") as temp:
    root = Path(temp)
    env = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
               XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"),
               XDG_CACHE_HOME=str(root / "cache"), NVIM_LOG_FILE=str(root / "nvim.log"),
               TEST_ROOT=str(root), TEST_MODULE=str(source))
    script = root / "test.lua"
    script.write_text(r'''
local api, root = vim.api, vim.env.TEST_ROOT
local function eq(a, b) assert(vim.deep_equal(a, b), vim.inspect({a, b})) end
local timestamp = os.time() - 100
local function write(path, text)
  local f = assert(io.open(path, 'wb')); f:write(text); f:close()
  -- Native timestamps tolerate a one-second FAT rounding difference on Linux.
  timestamp = timestamp + 5
  assert(vim.uv.fs_utime(path, timestamp, timestamp))
end
local function lines(buf) return api.nvim_buf_get_lines(buf or 0, 0, -1, false) end
local function event(name)
  api.nvim_exec_autocmds(name or 'FocusGained', {modeline = false, data = {status = 0}})
  vim.wait(20, function() return false end)
end
local function edit(path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  return api.nvim_get_current_buf()
end
local path = root .. '/file | $HOME % #.txt'
write(path, 'one\ntwo\nthree\nfour\nfive\n')
local source = edit(path)
vim.wo.foldmethod = 'manual'
vim.cmd('2,4fold')
api.nvim_win_set_cursor(0, {3, 1})
local view, win, cwd = vim.fn.winsaveview(), api.nvim_get_current_win(), vim.fn.getcwd()
local register = vim.fn.getreg('"')
dofile(vim.env.TEST_MODULE)
eq(vim.go.autoread, true)
eq(vim.bo.autoread, nil)
-- Reloading the helper must replace its own hooks rather than duplicate them.
dofile(vim.env.TEST_MODULE)
eq(#api.nvim_get_autocmds({group = 'SeeleExternalFiles'}), 3)
write(path, 'one\nexternally changed\nthree\nfour\nfive\n')
event()
eq(lines(), {'one', 'externally changed', 'three', 'four', 'five'})
eq(vim.bo.modified, false); eq(vim.fn.winsaveview(), view)
eq(api.nvim_get_current_win(), win); eq(vim.fn.getcwd(), cwd)
eq(vim.fn.getreg('"'), register); eq(vim.wo.foldmethod, 'manual')
-- Native reload leaves the previous file version in the normal undo tree.
vim.cmd.undo()
eq(lines(), {'one', 'two', 'three', 'four', 'five'})
vim.cmd.redo()
eq(lines(), {'one', 'externally changed', 'three', 'four', 'five'})
-- Atomic replacement (the usual formatter/VCS save) reloads too.
write(path .. '.replacement', 'replacement\n')
assert(os.rename(path .. '.replacement', path))
event('TermLeave'); eq(lines(), {'replacement'})
-- A modified buffer must not reload or open the native conflict question.
api.nvim_buf_set_lines(source, 0, -1, false, {'unsaved local edit'})
local undo = vim.fn.undotree()
write(path, 'another external version\n')
event(); eq(lines(), {'unsaved local edit'}); eq(vim.bo.modified, true)
eq(vim.fn.undotree(), undo)
-- Native noautoread remains a buffer-local opt-out.
vim.bo.modified = false
vim.bo.autoread = false
write(path, 'not reloaded by request\n')
event('TermClose'); eq(lines(), {'unsaved local edit'})
vim.bo.autoread = true
event(); eq(lines(), {'not reloaded by request'})
-- Inherited global opt-out and an explicit local opt-in keep native semantics.
vim.bo.autoread = nil
vim.go.autoread = false
write(path, 'globally opted out\n')
event(); eq(lines(), {'not reloaded by request'})
vim.bo.autoread = true
event(); eq(lines(), {'globally opted out'})
vim.bo.autoread = nil
vim.go.autoread = true
-- Hidden loaded buffers refresh without moving the current window.
vim.o.hidden = true
local second_path = root .. '/second.txt'
write(second_path, 'second\n')
local second = edit(second_path)
write(path, 'hidden external text\n')
write(second_path, 'current external text\n')
event(); eq(lines(source), {'hidden external text'})
eq(lines(second), {'current external text'})
eq(api.nvim_get_current_buf(), second); eq(api.nvim_get_current_win(), win)
-- A reload callback may delete a later buffer from the captured iteration list.
local doomed_path = root .. '/doomed.txt'
write(doomed_path, 'doomed\n')
local doomed = edit(doomed_path)
api.nvim_set_current_buf(second)
api.nvim_create_autocmd('FileChangedShellPost', {
  buffer = source, once = true,
  callback = function() api.nvim_buf_delete(doomed, {force = true}) end,
})
write(path, 'callback external text\n')
event(); eq(api.nvim_buf_is_valid(doomed), false)
eq(lines(source), {'callback external text'})
-- Special buffers and scheme names do not enter native file timestamp checking.
local special = api.nvim_create_buf(false, true)
api.nvim_buf_set_name(special, root .. '/special.txt')
api.nvim_buf_set_lines(special, 0, -1, false, {'scratch'})
vim.bo[special].modified = false
write(root .. '/special.txt', 'disk scratch replacement\n')
local uri = api.nvim_create_buf(true, false)
api.nvim_buf_set_name(uri, 'testscheme://localhost/file.txt')
api.nvim_buf_set_lines(uri, 0, -1, false, {'remote text'})
vim.bo[uri].modified = false
event(); eq(lines(special), {'scratch'}); eq(lines(uri), {'remote text'})
-- Deletion retains readable text and native warns; it never recreates the file.
assert(os.remove(second_path))
event(); eq(lines(second), {'current external text'})
eq(vim.fn.filereadable(second_path), 0)
local messages = vim.fn.execute('messages')
assert(messages:find('no longer available', 1, true), messages)
-- Returning during a command line or insertion defers timestamp checks.
write(path, 'deferred external text\n')
local function later(fn)
  vim.defer_fn(function()
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then io.stderr:write(err .. '\n'); vim.cmd.cquit() end
  end, 10)
end
api.nvim_input(':')
later(function()
  eq(api.nvim_get_mode().mode, 'c')
  event(); eq(lines(source), {'callback external text'})
  api.nvim_input('<Esc>')
  later(function()
    eq(api.nvim_get_mode().mode, 'n')
    vim.cmd.startinsert()
    later(function()
      assert(api.nvim_get_mode().mode:match('^i'))
      event(); eq(lines(source), {'callback external text'})
      vim.cmd.stopinsert()
      later(function()
        eq(api.nvim_get_mode().mode, 'n')
        event(); eq(lines(source), {'deferred external text'})
        print('External refresh: native reload, undo/view, dirty/opt-out, hidden/special, deletion and input-mode checks passed')
        vim.cmd('qa!')
      end)
    end)
  end)
end)
''')
    result = subprocess.run([editor, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                             "-c", "lua vim.schedule(function() local ok, err = xpcall(function() dofile(" + repr(str(script))
                             + ") end, debug.traceback); if not ok then io.stderr:write(tostring(err)); vim.cmd.cquit() end end)"], env=env, capture_output=True, text=True,
                            timeout=20)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    output = result.stdout + result.stderr
    if "Error executing" in output or "Error in " in output or "Lua callback:" in output:
        raise AssertionError(output)
    print(output, end="")
