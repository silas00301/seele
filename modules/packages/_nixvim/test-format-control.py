#!/usr/bin/env python3
"""Check the native format commands and status against real lsp-format."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

config = (Path(__file__).resolve().parent / "config.nix").read_text()
status = re.search(r'lualine_x = \[\s*\{\s*__unkeyed-1.__raw = \'\'(.*?)\'\';', config, re.S)[1]
action = re.search(r'key = "<leader>cf";\s*action = "<cmd>(.*?)<CR>";', config)[1]
with tempfile.TemporaryDirectory(prefix="seele-format-") as temp:
    script = Path(temp) / "check.lua"
    script.write_text('''
vim.opt.runtimepath:prepend(vim.env.LSP_FORMAT_DIR)
local formatter = require("lsp-format")
formatter.setup()
local status = ''' + status + '''
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "untouched" })
local tick = vim.b.changedtick
assert(status() == "")
vim.cmd("''' + action + '''")
assert(formatter.disabled and status() == "format off")
vim.cmd("''' + action + '''")
assert(not formatter.disabled and status() == "")
vim.cmd("FormatDisable lua")
assert(status() == "format off")
vim.bo.filetype = "python"
assert(status() == "")
vim.bo.filetype = "lua.markdown"
assert(status() == "format off")
vim.cmd("FormatEnable lua")
assert(status() == "")
vim.cmd("FormatDisable")
vim.cmd("FormatDisable markdown")
assert(status() == "format off")
vim.cmd("FormatEnable!")
assert(status() == "" and not formatter.disabled)
assert(vim.b.changedtick == tick, "toggling changed buffer contents")
print("format controls: global, filetype, compound type, reset passed")
vim.cmd("qa!")
''')
    env = {**os.environ, "HOME": temp, "XDG_CONFIG_HOME": temp,
           "XDG_STATE_HOME": temp, "XDG_DATA_HOME": temp}
    subprocess.run([os.environ.get("NVIM", "nvim"), "--headless", "-u", "NONE", "-i", "NONE", "-l", str(script)], env=env, check=True, timeout=20)
