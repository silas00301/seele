-- External tools may edit files while the editor is in the background.
-- Check only clean file buffers, so returning never opens a conflict prompt.
local api = vim.api
local function refresh()
  if api.nvim_get_mode().mode ~= 'n' then return end
  for _, buf in ipairs(api.nvim_list_bufs()) do
    -- A prior reload's autocommands can delete another buffer in this list.
    if api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == '' and not vim.bo[buf].modified
    then
      -- autoread is global-local: nil means inherit the global setting.
      local autoread = vim.bo[buf].autoread
      if autoread == nil then autoread = vim.go.autoread end
      local name = api.nvim_buf_get_name(buf)
      if autoread and name ~= '' and not name:match('^[%a][%w+.-]*://') then
        -- Native checktime owns reload/undo/view handling and deletion warnings.
        vim.cmd.checktime({ range = { buf } })
      end
    end
  end
end
api.nvim_create_autocmd({ 'FocusGained', 'TermLeave', 'TermClose' }, {
  group = api.nvim_create_augroup('SeeleExternalFiles', { clear = true }),
  callback = function() vim.schedule(refresh) end,
  desc = 'Refresh unedited files after external changes',
})
