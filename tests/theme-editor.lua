-- Run with: lua tests/theme-editor.lua modules/packages/_nixvim/theme.lua
local source = assert(io.open(arg[1])):read('*a')
local applied, callback, closed
local function fixture(state, flavor)
  applied, callback, closed = {}, nil, false
  vim = {
    env = { SEELE_THEME_STATE = state },
    json = { decode = function() if flavor == 'broken' then error('bad JSON') end return {flavor=flavor} end },
    o = {},
    cmd = { colorscheme = function(name) table.insert(applied, name) end },
    api = {
      nvim_create_augroup = function() return 1 end,
      nvim_create_autocmd = function() end,
    },
    schedule_wrap = function(fn) return fn end,
    uv = { new_fs_event = function() return {
      start = function(_, _, _, fn) callback = fn; return true end,
      stop = function() end,
      close = function() closed = true end,
    } end },
  }
  local original = io.open
  io.open = function() return {read=function() return '{}' end, close=function() end} end
  local result = assert(load(source .. '\nreturn "remaining configuration ran"', 'theme initialization'))()
  io.open = original
  assert(result == 'remaining configuration ran')
end
fixture(nil, 'mocha')
assert(#applied == 0, 'Other hosts must retain their theme and continue init')
fixture('/state', 'latte')
assert(applied[1] == 'catppuccin-latte' and vim.o.background == 'light')
vim.json.decode = function() return {flavor='mocha'} end
local original = io.open
io.open = function() return {read=function() return '{}' end, close=function() end} end
callback(nil, 'selection.json')
assert(applied[#applied] == 'catppuccin-mocha' and vim.o.background == 'dark')
local count = #applied
callback(nil, 'selection.json')
assert(#applied == count, 'Unchanged palette must not reload the editor')
vim.json.decode = function() return {flavor='latte | shell-command'} end
callback(nil, 'selection.json')
assert(#applied == count, 'Unknown flavors cannot reach commands')
io.open = original
fixture('/state', 'broken')
assert(#applied == 0)
print('Editor initialization continues on other hosts; live valid palettes apply and malformed selections are ignored')
