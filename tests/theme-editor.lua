-- Run with: lua tests/theme-editor.lua modules/packages/_nixvim/theme.lua
local source = assert(io.open(arg[1])):read('*a')
local applied, callback, selection, events, highlights, clears
local function palette()
  local result = {}
  for i = 0, 15 do result[string.format('base%02X', i)] = string.format('#%06x', i * 4096) end
  return result
end
local function fixture(state, mode)
  applied, callback, events, highlights, clears = {}, nil, {}, {}, 0
  selection = { version=2, id='flexoki-light', mode=mode, palette=palette() }
  package.loaded['mini.base16'] = { setup=function(config) table.insert(applied, config.palette) end }
  vim = {
    env = { SEELE_THEME_STATE=state },
    json = { decode=function() if selection == 'broken' then error('bad JSON') end return selection end },
    o = {}, g = { colors_name='catppuccin' },
    cmd = function(command) assert(command == 'highlight clear'); clears = clears + 1 end,
    api = {
      nvim_create_augroup=function() return 1 end,
      nvim_create_autocmd=function() end,
      nvim_exec_autocmds=function(event) table.insert(events, event) end,
      nvim_get_hl=function() return {fg=123, bg=456, italic=true} end,
      nvim_set_hl=function(_, name, value) highlights[name] = value end,
    },
    schedule_wrap=function(fn) return fn end,
    uv = { new_fs_event=function() return {
      start=function(_, _, _, fn) callback = fn; return true end,
      stop=function() end, close=function() end,
    } end },
  }
  assert(assert(load(source .. '\nreturn "continued"'))() == 'continued')
end
local original = io.open
io.open = function() return {read=function() return '{}' end, close=function() end} end
fixture(nil, 'dark')
assert(#applied == 0 and clears == 0, 'Unmanaged editors must continue without restyling')
fixture('/state', 'light')
assert(applied[1].base00 == selection.palette.base00 and vim.o.background == 'light')
assert(vim.g.colors_name == nil and events[1] == 'ColorScheme')
assert(highlights.Normal.bg == nil and highlights.Normal.fg == 123 and highlights.Normal.italic)
callback(nil, 'selection.json')
assert(#applied == 1, 'Unchanged palette must not reload')
selection.palette.base00 = '#abcdef'
callback(nil, 'selection.json')
assert(#applied == 2 and applied[2].base00 == '#abcdef', 'Same-ID palette edits must apply')
selection.mode = 'dark'
callback(nil, 'selection.json')
assert(vim.o.background == 'dark' and #applied == 3)
selection.palette.base00 = '#123456; command'
callback(nil, 'selection.json')
assert(#applied == 3 and clears == 3)
selection.palette = palette(); selection.palette.extra = '#123456'
callback(nil, 'selection.json'); assert(#applied == 3)
selection.palette = palette(); selection.palette.base0F = nil
callback(nil, 'selection.json'); assert(#applied == 3)
selection.palette = palette(); selection.mode = 'invalid'
callback(nil, 'selection.json'); assert(#applied == 3)
selection = 'broken'; callback(nil, 'selection.json'); assert(#applied == 3)
io.open = original
print('Editor Base16 palettes, transparency, live updates, malformed state and unmanaged initialization passed')
