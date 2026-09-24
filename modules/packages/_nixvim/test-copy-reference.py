#!/usr/bin/env python3
"""Run real Neovim source-reference mappings with a private clipboard provider."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def marker_free(parent):
    parent = parent.resolve()
    return parent.is_dir() and os.access(parent, os.W_OK) and not any(
        (ancestor / marker).exists()
        for ancestor in (parent, *parent.parents)
        for marker in ('.jj', '.git')
    )


def snapshot(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


def main():
    editor = shutil.which('nvim')
    if not editor:
        raise SystemExit('Neovim is required')
    candidates = [os.environ.get('XDG_RUNTIME_DIR'), '/dev/shm', tempfile.gettempdir(), Path.home()]
    temporary_base = next((Path(path) for path in candidates if path and marker_free(Path(path))), None)
    if temporary_base is None:
        raise SystemExit('No writable temporary directory outside a repository marker')
    with tempfile.TemporaryDirectory(prefix='seele-copy-reference-', dir=temporary_base) as temp:
        root = Path(temp)
        project = root / 'project with spaces'
        (project / '.jj').mkdir(parents=True)
        (project / '.jj' / 'untouched').write_text('private VCS state')
        (project / 'nested' / '.git').mkdir(parents=True)
        (project / 'worktree').mkdir()
        (project / 'worktree' / '.git').write_text('gitdir: /not/contacted')
        source = project / 'src' / 'quote\' $(touch SHOULD_NOT_EXIST) [x].lua'
        source.parent.mkdir()
        source.write_text('one\ntwo\nthree\nfour\nfive\n')
        (project / 'src' / 'linked.lua').symlink_to(source.name)
        baseline = snapshot(project)
        script = root / 'test.lua'
        script.write_text(r'''
local function eq(a, b) assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b)) end
local source = vim.env.TEST_SOURCE
local project = vim.env.TEST_PROJECT
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
local module = dofile(vim.env.TEST_MODULE)
module.setup()
local function edit(path)
  vim.cmd.edit({args = {path}, bang = true})
end
local function normal()
  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(escape, "nx", false)
end
local function mapped(mode, key)
  local mapping = vim.fn.maparg(" " .. key, mode, false, true)
  assert(mapping.desc:find("source reference"))
  mapping.callback()
end
edit(source)
vim.api.nvim_buf_set_lines(0, 1, 2, false, {"UNSAVED PRIVATE CONTENT"})
vim.api.nvim_win_set_cursor(0, {3, 1})
vim.fn.setreg('a', 'previous unnamed', 'v')
vim.fn.setreg('"', {points_to = 'a'})
vim.fn.setreg('0', 'previous yank', 'v')
vim.fn.setreg('/', 'previous search', 'v')
local registers = {vim.fn.getreginfo('"'), vim.fn.getreginfo('0'), vim.fn.getreginfo('/')}
local view, tick, undo = vim.fn.winsaveview(), vim.api.nvim_buf_get_changedtick(0), vim.fn.undotree()
mapped('n', 'cp')
local relative = "src/quote' $(touch SHOULD_NOT_EXIST) [x].lua"
eq(vim.fn.getreg('r'), relative .. ':3')
eq(registers, {vim.fn.getreginfo('"'), vim.fn.getreginfo('0'), vim.fn.getreginfo('/')})
eq(view, vim.fn.winsaveview())
eq(tick, vim.api.nvim_buf_get_changedtick(0))
eq(undo, vim.fn.undotree())
if vim.env.TEST_PROVIDER == 'none' then
  assert(messages[#messages][1]:find('no clipboard provider', 1, true))
elseif vim.env.TEST_PROVIDER == 'failure' then
  assert(messages[#messages][1]:find('clipboard provider failed', 1, true))
  eq(messages[#messages][2], vim.log.levels.WARN)
else
  eq(clipboard, {{relative .. ':3'}, 'v'})
end
mapped('n', 'cP')
eq(vim.fn.getreg('r'), source .. ':3')
vim.cmd('2,4CopyReference')
eq(vim.fn.getreg('r'), relative .. ':2-4')
vim.cmd('CopyReference!')
eq(vim.fn.getreg('r'), source .. ':3')
-- Real visual selections, including reverse, linewise, blockwise and exclusive.
for _, selection in ipairs({
  {'v', {2, 0}, {4, 1}, 'inclusive', '2-4'},
  {'v', {4, 1}, {2, 0}, 'inclusive', '2-4'},
  {'V', {2, 0}, {4, 1}, 'inclusive', '2-4'},
  {'\022', {2, 0}, {4, 1}, 'inclusive', '2-4'},
  {'v', {2, 0}, {4, 0}, 'exclusive', '2-3'},
}) do
  normal()
  vim.o.selection = selection[4]
  vim.api.nvim_win_set_cursor(0, selection[2])
  vim.cmd.normal({args = {selection[1]}, bang = true})
  vim.api.nvim_win_set_cursor(0, selection[3])
  local mode, anchor, cursor = vim.fn.mode(), vim.fn.getpos('v'), vim.fn.getpos('.')
  mapped('x', 'cp')
  eq(vim.fn.getreg('r'), relative .. ':' .. selection[5])
  eq({mode, anchor, cursor}, {vim.fn.mode(), vim.fn.getpos('v'), vim.fn.getpos('.')})
end
normal()
-- Nested Git and worktree markers win over an ancestor Jujutsu marker.
for _, directory in ipairs({'nested', 'worktree'}) do
  edit(project .. '/' .. directory .. '/new.lua')
  mapped('n', 'cp')
  eq(vim.fn.getreg('r'), 'new.lua:1')
end
-- No repository falls back to the full path, even when cwd is a repository.
vim.api.nvim_set_current_dir(project)
edit(vim.env.TEST_ROOT .. '/outside/new.lua')
mapped('n', 'cp')
eq(vim.fn.getreg('r'), vim.env.TEST_ROOT .. '/outside/new.lua:1')
vim.api.nvim_buf_delete(vim.fn.bufnr(source), {force = true})
edit(project .. '/src/linked.lua')
mapped('n', 'cp')
eq(vim.fn.getreg('r'), 'src/linked.lua:1')
-- Refusals preserve the previous reference and never send to the provider.
local function refused()
  local previous, before = vim.fn.getreg('r'), vim.deepcopy(clipboard)
  mapped('n', 'cp')
  eq(vim.fn.getreg('r'), previous)
  eq(clipboard, before)
  eq(messages[#messages][2], vim.log.levels.WARN)
end
for _, name in ipairs({'bad:line.lua', 'bad\nline.lua', 'bad\tline.lua'}) do
  edit(project .. '/' .. name)
  refused()
end
vim.cmd.enew({bang = true})
refused()
vim.api.nvim_buf_set_name(0, project .. '/special')
vim.bo.buftype = 'nofile'
refused()
vim.bo.buftype = ''
vim.api.nvim_buf_set_name(0, project)
refused()
vim.cmd('qa!')
''')
        for provider in ('success', 'none', 'failure'):
            env = dict(os.environ, TEST_ROOT=str(root), TEST_PROJECT=str(project),
                       TEST_SOURCE=str(source), TEST_PROVIDER=provider,
                       TEST_MODULE=str(Path(__file__).with_name('copy-reference.lua').resolve()),
                       HOME=str(root / 'home'), XDG_CONFIG_HOME=str(root / 'config'),
                       XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                       XDG_CACHE_HOME=str(root / 'cache'))
            result = subprocess.run([editor, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
                                     '-l', str(script)], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=20)
            if result.returncode:
                raise AssertionError(provider + ': ' + result.stdout + result.stderr)
            assert snapshot(project) == baseline, 'Repository changed while copying a reference'
            assert not (root / 'SHOULD_NOT_EXIST').exists()
        print('Source reference: real normal/visual mappings, project roots, paths, state and clipboard checks passed')


if __name__ == '__main__':
    main()
