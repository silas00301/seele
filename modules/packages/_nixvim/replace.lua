-- Search and replace through grug-far. Lowercase scopes the current file and
-- uppercase the working directory, matching the sd/sD and ss/sS search pairs.
local M = {}

local function current_file()
  if vim.bo.buftype ~= "" then return nil, "This buffer is not a file" end
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then return nil, "Name this file before replacing in it" end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  -- Control characters would split the paths input into several entries.
  if path:find("%c") then return nil, "This filename cannot be used as a replace scope" end
  -- grug-far separates paths on spaces and reads "\ " as a literal one.
  return (path:gsub(" ", "\\ "))
end

local function open(scope_file, visual)
  local prefills = {}
  if scope_file then
    local path, err = current_file()
    if not path then
      vim.notify(err, vim.log.levels.WARN, { title = "Replace" })
      return
    end
    prefills.paths = path
  end
  local grug = require("grug-far")
  if visual then
    grug.with_visual_selection({ prefills = prefills })
  else
    prefills.search = vim.fn.expand("<cword>")
    grug.open({ prefills = prefills })
  end
end

function M.setup()
  for _, binding in ipairs({
    { "<leader>sr", true, "Replace in current file" },
    { "<leader>sR", false, "Replace in working directory" },
  }) do
    local key, scope_file, desc = binding[1], binding[2], binding[3]
    vim.keymap.set("n", key, function() open(scope_file, false) end, { desc = desc })
    vim.keymap.set("x", key, function() open(scope_file, true) end, { desc = desc })
  end
end

return M
