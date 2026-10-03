#!/usr/bin/env python3
"""Drive the real search-and-replace mappings through grug-far and ripgrep.

Requires `nvim`, `rg`, and a grug-far.nvim checkout named by GRUG_FAR.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    editor = shutil.which('nvim')
    ripgrep = shutil.which('rg')
    plugin = os.environ.get('GRUG_FAR')
    if not editor or not ripgrep or not plugin:
        raise SystemExit('Neovim, ripgrep and GRUG_FAR=<grug-far.nvim checkout> are required')
    with tempfile.TemporaryDirectory(prefix='seele-replace-') as temp:
        root = Path(temp)
        project = root / 'project'
        source = project / 'src' / 'with spaces [x].lua'
        source.parent.mkdir(parents=True)
        source.write_text('alpha beta\nbeta gamma alpha\n')
        other = project / 'other.lua'
        other.write_text('alpha\nbeta gamma\n')
        script = root / 'test.lua'
        script.write_text(r'''
local function eq(a, b) assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b)) end
local function wait(check, what) assert(vim.wait(10000, check, 20), "timed out waiting for " .. what) end
local messages = {}
vim.notify = function(message, level) table.insert(messages, {message, level}) end
vim.g.mapleader = " "
vim.opt.runtimepath:prepend(vim.env.GRUG_FAR)
require("grug-far").setup({ engines = { ripgrep = { path = vim.env.TEST_RG } } })
dofile(vim.env.TEST_MODULE).setup()
local grug = require("grug-far")
local inputs = require("grug-far.inputs")
local project, source, other = vim.env.TEST_PROJECT, vim.env.TEST_SOURCE, vim.env.TEST_OTHER
vim.api.nvim_set_current_dir(project)

local function mapped(mode, key, desc)
  local mapping = vim.fn.maparg(" " .. key, mode, false, true)
  eq(mapping.desc, desc)
  mapping.callback()
end
local function values(inst) return inputs.getValues(inst._context, inst._buf) end
local function idle(inst)
  local status = inst:get_status_info().status
  return status ~= nil and status ~= "progress"
end
local function replace(inst, replacement)
  wait(function() return idle(inst) end, "the search to settle")
  inst:update_input_values({ replacement = replacement }, false)
  wait(function() return values(inst).replacement == replacement end, "the replacement input")
  inst:search()
  wait(function() return idle(inst) and (inst:get_status_info().stats or {}).matches end, "the preview")
  local stats = inst:get_status_info().stats
  inst:replace()
  wait(function()
    local info = inst:get_status_info()
    return info.status == "success" and (info.actionMessage or ""):find("replace completed")
  end, "the replacement")
  return stats
end
local function close(inst)
  inst:close()
  wait(function() return not inst:is_valid() end, "the instance to close")
end
local function lines(path) return vim.fn.readfile(path) end

-- Lowercase scopes the current file: the other match stays untouched.
vim.cmd.edit({ args = { vim.fn.fnameescape(source) } })
vim.api.nvim_win_set_cursor(0, { 1, 1 })
mapped("n", "sr", "Replace in current file")
local inst = grug.get_instance()
assert(inst, "no grug-far instance for the file scope")
wait(function() return inst._context.state.status ~= nil end, "the instance")
local initial = values(inst)
eq(initial.search, "alpha")
eq(initial.paths, (source:gsub(" ", "\\ ")))
eq(replace(inst, "omega"), { files = 1, matches = 2 })
close(inst)
eq(lines(source), { "omega beta", "beta gamma omega" })
eq(lines(other), { "alpha", "beta gamma" })

-- A charwise selection becomes a literal search in that file only.
vim.cmd.edit({ args = { vim.fn.fnameescape(source) }, bang = true })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd.normal({ args = { "v" }, bang = true })
vim.api.nvim_win_set_cursor(0, { 2, 9 })
mapped("x", "sr", "Replace in current file")
inst = grug.get_instance()
wait(function() return inst._context.state.status ~= nil end, "the visual instance")
local visual = values(inst)
eq(visual.search, "beta gamma")
eq(visual.paths, (source:gsub(" ", "\\ ")))
assert(visual.flags:find("--fixed-strings", 1, true), visual.flags)
close(inst)
vim.cmd.stopinsert()
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

-- Uppercase leaves the scope at the working directory.
vim.cmd.edit({ args = { vim.fn.fnameescape(other) }, bang = true })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
mapped("n", "sR", "Replace in working directory")
inst = grug.get_instance()
wait(function() return inst._context.state.status ~= nil end, "the project instance")
eq(values(inst).paths, "")
eq(values(inst).search, "beta")
eq(replace(inst, "delta"), { files = 2, matches = 3 })
close(inst)
eq(lines(source), { "omega delta", "delta gamma omega" })
eq(lines(other), { "alpha", "delta gamma" })

-- Buffers that are not files are refused before grug-far opens.
local function refused(key)
  local before = #messages
  local windows = #vim.api.nvim_list_wins()
  mapped("n", key, "Replace in current file")
  eq(#vim.api.nvim_list_wins(), windows)
  eq(#messages, before + 1)
  eq(messages[#messages][2], vim.log.levels.WARN)
end
vim.cmd.enew({ bang = true })
refused("sr")
vim.api.nvim_buf_set_name(0, project .. "/scratch")
vim.bo.buftype = "nofile"
refused("sr")
vim.bo.buftype = ""
vim.api.nvim_buf_set_name(0, project .. "/bad\tname.lua")
refused("sr")
vim.cmd("qa!")
''')
        env = dict(os.environ, GRUG_FAR=plugin, TEST_RG=ripgrep,
                   TEST_MODULE=str(Path(__file__).with_name('replace.lua').resolve()),
                   TEST_PROJECT=str(project), TEST_SOURCE=str(source), TEST_OTHER=str(other),
                   HOME=str(root / 'home'), XDG_CONFIG_HOME=str(root / 'config'),
                   XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                   XDG_CACHE_HOME=str(root / 'cache'))
        result = subprocess.run([editor, '--headless', '-u', 'NONE', '-i', 'NONE', '-n',
                                 '-l', str(script)], cwd=project, env=env,
                                capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        print('Replace: real file/project/visual mappings through grug-far and ripgrep passed')


if __name__ == '__main__':
    main()
