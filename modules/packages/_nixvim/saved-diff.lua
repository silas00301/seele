-- A comparison owns only two scratch buffers and a tab, never the source window.
local api, uv = vim.api, vim.uv
local limit = 2 * 1024 * 1024
local line_limit = 20000
local session

local function quiet(fn)
  local events, autochdir = vim.o.eventignore, vim.o.autochdir
  vim.o.eventignore, vim.o.autochdir = 'all', false
  local ok, result = pcall(fn)
  vim.o.eventignore, vim.o.autochdir = events, autochdir
  if not ok then error(result) end
  return result
end

local function close()
  local old = session
  if not old then return end
  session = nil
  quiet(function()
    for _, win in ipairs(old.windows) do
      if api.nvim_win_is_valid(win) then
        if vim.tbl_contains(old.buffers, api.nvim_win_get_buf(win)) then
          -- If the user closed the original tab, Neovim still needs one window.
          local closed = pcall(api.nvim_win_close, win, true)
          if not closed then api.nvim_win_set_buf(win, api.nvim_create_buf(true, false)) end
        end
        if api.nvim_win_is_valid(win) then
          api.nvim_win_call(win, function()
            vim.cmd('diffoff')
            vim.wo.winbar = old.winbar
          end)
        end
      end
    end
    for _, buf in ipairs(old.buffers) do
      if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf, { force = true }) end
    end
    if api.nvim_win_is_valid(old.origin) then api.nvim_set_current_win(old.origin) end
  end)
end

local function read_saved(path, encoding, source_format)
  -- Reject special files before opening; NONBLOCK also covers a FIFO replacement race.
  local stat, err = uv.fs_stat(path)
  if not stat then error('Cannot read saved file: ' .. tostring(err)) end
  if stat.type ~= 'file' then error('Saved path is not a regular file') end
  if stat.size > limit then error('Saved file exceeds the 2 MiB comparison limit') end
  local fd
  fd, err = uv.fs_open(path, uv.constants.O_RDONLY + uv.constants.O_NONBLOCK, 0)
  if not fd then error('Cannot read saved file: ' .. tostring(err)) end
  local ok, data = pcall(function()
    local opened = assert(uv.fs_fstat(fd))
    if opened.type ~= 'file' or opened.size > limit then error('Saved file changed while opening') end
    -- Read at most limit + 1, even if a writer grows the file after stat.
    local chunks, size = {}, 0
    while size <= limit do
      local chunk = assert(uv.fs_read(fd, math.min(65536, limit + 1 - size), size))
      if #chunk == 0 then break end
      chunks[#chunks + 1], size = chunk, size + #chunk
    end
    if size > limit then error('Saved file exceeds the 2 MiB comparison limit') end
    return table.concat(chunks)
  end)
  uv.fs_close(fd)
  if not ok then error(data) end
  if encoding ~= '' and encoding ~= 'utf-8' then
    local converted = vim.fn.iconv(data, encoding, 'utf-8')
    if converted == '' and data ~= '' then error('Cannot decode saved file as ' .. encoding) end
    data = converted
  end
  data = data:gsub('^\239\187\191', '')
  if data:find('\0', 1, true) then error('Binary saved files cannot be compared') end
  local without_crlf = data:gsub('\r\n', '')
  local format = data:find('\r\n', 1, true) and not without_crlf:find('\n', 1, true) and 'dos' or 'unix'
  if source_format == 'mac' and not data:find('\n', 1, true) then format = 'mac' end
  if format == 'dos' then data = data:gsub('\r\n', '\n') end
  if format == 'mac' then data = data:gsub('\r', '\n') end
  local eol = data:sub(-1) == '\n'
  local _, breaks = data:gsub('\n', '')
  if breaks + (eol and 0 or 1) > line_limit then
    error('Saved file exceeds the 20000 line comparison limit')
  end
  if eol then data = data:sub(1, -2) end
  return vim.split(data, '\n', { plain = true }), eol, format
end

local function scratch(lines, title, eol, format)
  local buf = api.nvim_create_buf(false, true)
  session.buffers[#session.buffers + 1] = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].undolevels = -1
  vim.bo[buf].modeline = false
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].endofline = eol
  vim.bo[buf].fileformat = format
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  api.nvim_buf_set_name(buf, 'saved-diff://' .. title)
  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', key, close, { buffer = buf, desc = 'Close saved-file comparison' })
  end
  return buf
end

local function compare()
  if session then close(); return end
  local source = api.nvim_get_current_buf()
  local path = api.nvim_buf_get_name(source)
  if path == '' or vim.bo[source].buftype ~= '' then
    error('SavedDiff needs a named, ordinary file buffer')
  end
  if vim.bo[source].binary then error('Binary buffers cannot be compared') end
  local current_lines = api.nvim_buf_line_count(source)
  if current_lines > line_limit then
    error('Current buffer exceeds the 20000 line comparison limit')
  end
  if api.nvim_buf_get_offset(source, current_lines) > limit then
    error('Current buffer exceeds the 2 MiB comparison limit')
  end
  local lines, eol, format = read_saved(path, vim.bo[source].fileencoding, vim.bo[source].fileformat)
  local current = api.nvim_buf_get_lines(source, 0, current_lines, false)
  session = { origin = api.nvim_get_current_win(), winbar = vim.wo.winbar, windows = {}, buffers = {} }
  quiet(function()
    local saved = scratch(lines, 'Saved on disk', eol, format)
    local edited = scratch(current, 'Current buffer snapshot', vim.bo[source].endofline, vim.bo[source].fileformat)
    -- New tab isolates native diff options/folding from every existing window.
    vim.cmd('keepalt tab split')
    session.windows[1] = api.nvim_get_current_win()
    api.nvim_win_set_buf(0, saved)
    vim.cmd('keepalt rightbelow vsplit')
    session.windows[2] = api.nvim_get_current_win()
    api.nvim_win_set_buf(0, edited)
    for i, win in ipairs(session.windows) do
      api.nvim_win_call(win, function()
        local buf = api.nvim_win_get_buf(win)
        vim.wo.winbar = (i == 1 and 'Saved on disk' or 'Current buffer snapshot')
          .. ' [' .. vim.bo[buf].fileformat .. ', '
          .. (vim.bo[buf].endofline and 'final newline' or 'no final newline') .. ']  q: close'
        vim.cmd('diffthis')
      end)
    end
  end)
end

api.nvim_create_user_command('SavedDiff', function()
  local ok, err = pcall(compare)
  if not ok then
    if session then pcall(close) end
    vim.notify(tostring(err), vim.log.levels.WARN, { title = 'Saved-file comparison' })
  end
end, { desc = 'Toggle read-only comparison with the saved file' })
api.nvim_create_user_command('SavedDiffClose', close, { desc = 'Close saved-file comparison' })

-- Ordinary :q, :tabclose, :bwipeout, and manually replacing either pane also
-- retire its partner. Scheduled cleanup runs after Neovim finishes the event.
api.nvim_create_autocmd({ 'WinClosed', 'BufWinLeave' }, {
  group = api.nvim_create_augroup('SeeleSavedDiff', { clear = true }),
  callback = function(event)
    local old = session
    if not old then return end
    local owned = event.event == 'WinClosed'
      and (tonumber(event.match) == old.origin
        or vim.tbl_contains(old.windows, tonumber(event.match)))
      or event.event == 'BufWinLeave' and vim.tbl_contains(old.buffers, event.buf)
    if owned then
      vim.schedule(function() if session == old then close() end end)
    end
  end,
})
