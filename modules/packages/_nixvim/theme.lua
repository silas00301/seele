-- The active desktop opts in; portable Neovim and other hosts keep their theme.
local state = vim.env.SEELE_THEME_STATE
if not state or state == "" then return end
local current
local function apply()
  local file = io.open(state .. "/selection.json", "r")
  if not file then return end
  local bytes = file:read(32769)
  file:close()
  if not bytes or #bytes > 32768 then return end
  local ok, theme = pcall(vim.json.decode, bytes)
  if not ok or type(theme) ~= "table" then return end
  local flavor = theme.flavor
  if flavor ~= "mocha" and flavor ~= "macchiato" and flavor ~= "frappe" and flavor ~= "latte" then return end
  if current == flavor then return end
  vim.o.background = flavor == "latte" and "light" or "dark"
  vim.cmd.colorscheme("catppuccin-" .. flavor)
  current = flavor
end
local group = vim.api.nvim_create_augroup("SeeleTheme", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, { group = group, callback = apply })
local watcher = vim.uv.new_fs_event()
if watcher then
  local ok = watcher:start(state, {}, vim.schedule_wrap(function(error, name)
    if not error and (name == "selection.json" or not name) then apply() end
  end))
  if ok then
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, once = true, callback = function()
      watcher:stop()
      watcher:close()
    end })
  else
    watcher:close()
  end
end
apply()
