#!/usr/bin/env python3
"""Exercise explicit diagnostic copying with real Neovim and private providers."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    editor = shutil.which('nvim')
    if not editor:
        raise SystemExit('Neovim is required')
    helpers = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix='seele-diagnostics-') as temporary:
        root = Path(temporary)
        project = root / 'project with spaces'
        (project / '.jj').mkdir(parents=True)
        marker = project / '.jj' / 'untouched'
        marker.write_text('never snapshot or mutate VCS state')
        source = project / "quote' [x].lua"
        original = 'PRIVATE SOURCE CONTENT\n' * 10
        source.write_text(original)
        script = root / 'check.lua'
        script.write_text(r'''
local function eq(a, b) assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b)) end
local messages, clipboard = {}, {}
vim.notify = function(message, level) table.insert(messages, {message, level}) end
vim.g.mapleader = " "
vim.g.clipboard = {
  name = "private fixture",
  copy = {
    ["+"] = function(lines, kind)
      if vim.env.TEST_PROVIDER == "failure" then error("fixture provider failure") end
      clipboard = {lines, kind}
    end,
    ["*"] = function() error("primary selection must not be touched") end,
  },
  paste = { ["+"] = function() return clipboard end, ["*"] = function() return {{"primary"}, "v"} end },
  cache_enabled = 0,
}
if vim.env.TEST_PROVIDER == "none" then vim.g.loaded_clipboard_provider = 0 end
local reference = dofile(vim.env.TEST_HELPERS .. "/copy-reference.lua")
reference.setup()
local module = dofile(vim.env.TEST_HELPERS .. "/copy-diagnostics.lua")
module.setup(reference.reference)
vim.cmd.edit({args = {vim.env.TEST_SOURCE}})
vim.api.nvim_buf_set_lines(0, 0, 1, false, {"UNSAVED PRIVATE CONTENT"})
local buffer = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_create_namespace("test diagnostics")
local ns2 = vim.api.nvim_create_namespace("second provider")
vim.diagnostic.config({ virtual_text = false, signs = false, underline = false })
local diagnostics = {
  {lnum=4, col=3, message="last message", severity=2},
  {lnum=0, col=1, end_lnum=2, end_col=1, message="first line\nsecond line", severity=1, source="LSP", code="E001"},
  {lnum=2, col=0, end_lnum=3, end_col=0, message="ends before line four", severity=4},
}
vim.diagnostic.set(ns, buffer, diagnostics)
vim.diagnostic.set(ns2, buffer, {{lnum=2,col=0,message="info",severity=3,code=7}})
vim.api.nvim_win_set_cursor(0, {3, 2})
vim.fn.setreg('a', 'previous unnamed', 'v')
vim.fn.setreg('"', {points_to = 'a'})
vim.fn.setreg('0', 'previous yank', 'v')
vim.fn.setreg('/', 'previous search', 'v')
local registers = {vim.fn.getreginfo('"'), vim.fn.getreginfo('0'), vim.fn.getreginfo('/')}
local view, tick, undo = vim.fn.winsaveview(), vim.api.nvim_buf_get_changedtick(0), vim.fn.undotree()
local before = vim.deepcopy(vim.diagnostic.get(0))
local function mapped(key)
  local mapping = vim.fn.maparg(' ' .. key, 'n', false, true)
  assert(mapping.desc:find('diagnostics'))
  mapping.callback()
end
mapped('cd')
local path = "quote' [x].lua"
local expected = path .. ':1:2 [ERROR] (LSP:E001)\n  first line\n  second line\n\n'
  .. path .. ':3:1 [INFO] (7)\n  info\n\n'
  .. path .. ':3:1 [HINT]\n  ends before line four'
eq(vim.fn.getreg('r'), expected)
eq(vim.fn.getregtype('r'), 'v')
assert(not expected:find('PRIVATE CONTENT', 1, true))
eq(registers, {vim.fn.getreginfo('"'), vim.fn.getreginfo('0'), vim.fn.getreginfo('/')})
eq(view, vim.fn.winsaveview())
eq(tick, vim.api.nvim_buf_get_changedtick(0))
eq(undo, vim.fn.undotree())
eq(before, vim.diagnostic.get(0))
if vim.env.TEST_PROVIDER == 'none' then
  assert(messages[#messages][1]:find('no clipboard provider', 1, true))
elseif vim.env.TEST_PROVIDER == 'failure' then
  assert(messages[#messages][1]:find('clipboard provider failed', 1, true))
else
  eq(clipboard, {vim.split(expected, '\n', {plain=true}), 'v'})
end
vim.cmd('CopyDiagnostics')
eq(vim.fn.getreg('r'), expected)
mapped('cD')
assert(vim.fn.getreg('r'):find(':5:4 [WARN]\n  last message', 1, true))
local all = vim.fn.getreg('r')
vim.cmd('CopyDiagnostics!')
eq(vim.fn.getreg('r'), all)
vim.cmd('1,3CopyDiagnostics')
eq(vim.fn.getreg('r'), expected)
local function rejected(command, fragment)
  local saved, copied = vim.fn.getreginfo('r'), vim.deepcopy(clipboard)
  vim.cmd(command)
  assert(messages[#messages][1]:find(fragment, 1, true), messages[#messages][1])
  eq(saved, vim.fn.getreginfo('r'))
  eq(copied, clipboard)
end
rejected('4CopyDiagnostics', 'No diagnostics') -- exclusive end column zero
rejected('9CopyDiagnostics', 'No diagnostics')
vim.diagnostic.reset(ns2, buffer)
vim.diagnostic.set(ns, buffer, {{lnum=0,col=0,message='a\r\nb\27[31m',source='bad\nsource',code='x\t',severity=2}})
vim.cmd('CopyDiagnostics!')
eq(vim.fn.getreg('r'), path .. ':1:1 [WARN] (bad\\x0Asource:x\\x09)\n  a\n  b\\x1B[31m')
local many = {}
for i=1,501 do many[i] = {lnum=0,col=0,message='issue '..i,severity=1} end
vim.diagnostic.set(ns, buffer, many)
rejected('CopyDiagnostics!', 'limit: 500')
table.remove(many)
vim.diagnostic.set(ns, buffer, many)
vim.cmd('CopyDiagnostics!')
assert(messages[#messages][1]:find('500 diagnostics', 1, true))
vim.diagnostic.set(ns, buffer, {{lnum=0,col=0,message=string.rep('x',256*1024),severity=1}})
rejected('CopyDiagnostics!', '256 KiB')
vim.diagnostic.set(ns, buffer, {{lnum=0,col=0,message=string.rep('x',257*1024),severity=1}})
rejected('CopyDiagnostics!', '256 KiB')
vim.diagnostic.set(ns, buffer, {
  {lnum=0,col=0,message=string.rep('x',130*1024),severity=1},
  {lnum=1,col=0,message=string.rep('y',130*1024),severity=2},
})
rejected('CopyDiagnostics!', '256 KiB')
-- Escaping/indentation growth is part of the output byte limit too.
vim.diagnostic.set(ns, buffer, {{lnum=0,col=0,message=string.rep('\27',70*1024),severity=1}})
rejected('CopyDiagnostics!', '256 KiB')
vim.api.nvim_buf_set_name(buffer, vim.env.TEST_SOURCE .. ':ambiguous')
rejected('CopyDiagnostics!', 'cannot be represented')
vim.bo.buftype = 'nofile'
rejected('CopyDiagnostics!', 'not a source file')
vim.bo.buftype = ''
vim.api.nvim_buf_set_name(buffer, '')
rejected('CopyDiagnostics!', 'Name this file')
vim.cmd('qa!')
''')
        for provider in ('success', 'none', 'failure'):
            private = root / provider
            private.mkdir()
            env = dict(os.environ, HOME=str(private), XDG_CONFIG_HOME=str(private / 'config'),
                       XDG_DATA_HOME=str(private / 'data'), XDG_STATE_HOME=str(private / 'state'),
                       XDG_CACHE_HOME=str(private / 'cache'), TEST_HELPERS=str(helpers),
                       TEST_SOURCE=str(source), TEST_PROVIDER=provider)
            subprocess.run([editor, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
                            '-l', str(script)], env=env, check=True, timeout=30)
        assert source.read_text() == original
        assert marker.read_text() == 'never snapshot or mutate VCS state'
        print('PASS: diagnostic ranges, ordering, metadata, bounds, clipboard modes, editor/file preservation')


if __name__ == '__main__':
    main()
