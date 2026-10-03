#!/usr/bin/env python3
"""Exercise the configured Enter mapping against the installed nvim-cmp API."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent
config = (root / "config.nix").read_text()
mapping = re.search(r'"<CR>" = \'\'(.*?)\'\';', config, re.S)[1]
preselect = re.search(r'preselect = "([^"]+)";', config)[1]
completeopt = re.search(r'completion.completeopt = "([^"]+)";', config)[1]
cmp_dir = Path(os.environ["CMP_DIR"]).resolve()
with tempfile.TemporaryDirectory(prefix="seele-completion-") as temp:
    script = Path(temp) / "check.lua"
    script.write_text('''
vim.opt.runtimepath:prepend(vim.env.CMP_DIR)
local cmp = require("cmp")
local mapping = ''' + mapping + '''
cmp.setup({ preselect = ''' + preselect + ''', completion = { completeopt = "''' + completeopt + '''" } })
assert(cmp.get_config().preselect == cmp.PreselectMode.None)
assert(cmp.get_config().completion.completeopt:find("noselect", 1, true))
-- The real confirmation API observes this controlled view. The test never
-- replaces cmp.confirm or cmp.mapping.confirm, which own fallback semantics.
local visible, selected, accepted = false, nil, 0
cmp.core.view.visible = function() return visible end
cmp.core.view.get_selected_entry = function() return selected end
cmp.core.confirm = function(_, entry, options)
  assert(entry == selected and options.behavior == cmp.ConfirmBehavior.Replace)
  accepted = accepted + 1
end
for _, mode in ipairs({ "i", "s", "c" }) do
  local fallback = 0
  local function normal_enter() fallback = fallback + 1 end
  visible, selected = false, nil
  mapping[mode](normal_enter)
  assert(fallback == 1, mode .. ": closed menu swallowed Enter")
  visible, selected = true, nil
  mapping[mode](normal_enter)
  assert(fallback == 2, mode .. ": unselected menu swallowed Enter")
  local before = accepted
  selected = { completion_item = { label = "chosen" } }
  mapping[mode](normal_enter)
  assert(accepted == before + 1 and fallback == 2, mode .. ": explicit selection not confirmed")
end
print("completion confirmation: all modes passed")
vim.cmd("qa!")
''')
    env = {**os.environ, "HOME": temp, "XDG_CONFIG_HOME": temp,
           "XDG_STATE_HOME": temp, "XDG_DATA_HOME": temp, "CMP_DIR": str(cmp_dir)}
    subprocess.run([os.environ.get("NVIM", "nvim"), "--headless", "-u", "NONE", "-i", "NONE", "-l", str(script)], env=env, check=True, timeout=20)
