-- Copy locations, never buffer contents. Root discovery only inspects markers.
local M = {}

local function project_root(directory)
  while directory do
    local jj = vim.uv.fs_stat(directory .. "/.jj")
    local git = vim.uv.fs_stat(directory .. "/.git")
    if (jj and jj.type == "directory") or (git and (git.type == "directory" or git.type == "file")) then
      return directory
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then break end
    directory = parent
  end
end

local function reference(absolute, first, last)
  if vim.bo.buftype ~= "" then return nil, "This buffer is not a source file" end
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then return nil, "Name this file before copying a reference" end
  if path:sub(1, 1) ~= "/" then path = vim.fs.joinpath(vim.uv.cwd(), path) end
  path = vim.fs.normalize(path)
  -- Colons collide with the line suffix; controls can split or disguise it.
  if path:find("[:%c]") then return nil, "This filename cannot be represented as path:line" end
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type ~= "file" then return nil, "This path is not a regular file" end
  if not absolute then
    local root = project_root(vim.fs.dirname(path))
    if root then path = path:sub(#root + (root == "/" and 1 or 2)) end
  end
  return path .. ":" .. first .. (last ~= first and ("-" .. last) or "")
end

function M.copy(absolute, first, last)
  first = first or vim.api.nvim_win_get_cursor(0)[1]
  last = last or first
  local value, err = reference(absolute, math.min(first, last), math.max(first, last))
  if not value then
    vim.notify(err, vim.log.levels.WARN, { title = "Source reference" })
    return
  end
  -- A named register is a dependable local result even for asynchronous OSC 52
  -- providers, which cannot acknowledge the terminal's eventual clipboard write.
  vim.fn.setreg("r", value, "v")
  local message = 'Source reference copied to register r ("rp)'
  local level = vim.log.levels.INFO
  if vim.fn.has("clipboard") == 1 then
    local ok = pcall(vim.fn.setreg, "+", value, "v")
    if ok then
      message = message .. "; sent to clipboard provider"
    else
      message = message .. "; clipboard provider failed"
      level = vim.log.levels.WARN
    end
  else
    message = message .. "; no clipboard provider"
  end
  vim.notify(message, level, { title = "Source reference" })
end

local function copy_selection(absolute)
  local mode = vim.fn.mode()
  local positions = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."), {
    type = mode,
    exclusive = vim.o.selection == "exclusive",
  })
  if #positions > 0 then
    M.copy(absolute, positions[1][1][2], positions[#positions][2][2])
  end
end

function M.setup()
  vim.api.nvim_create_user_command("CopyReference", function(args)
    M.copy(args.bang, args.line1, args.line2)
  end, { bang = true, range = true, desc = "Copy source reference (! uses absolute path)" })
  for _, binding in ipairs({ { "<leader>cp", false }, { "<leader>cP", true } }) do
    local absolute = binding[2]
    local desc = absolute and "Copy absolute source reference" or "Copy source reference"
    vim.keymap.set("n", binding[1], function() M.copy(absolute) end, { desc = desc })
    vim.keymap.set("x", binding[1], function() copy_selection(absolute) end, { desc = desc })
  end
end

return M
