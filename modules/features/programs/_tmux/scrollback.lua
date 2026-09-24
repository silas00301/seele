-- A private editor session: terminal output is data, never editor configuration.
vim.opt.modeline = false
vim.opt.exrc = false
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.undolevels = -1
vim.opt.shada = ""
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.clipboard = ""
vim.opt.shelltemp = false
vim.opt.history = 0
vim.opt.wrap = true
vim.opt.linebreak = false
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.mouse = "a"
vim.opt.statusline = " Scrollback  ·  / search  ·  v/V/C-v select  ·  y copy and close  ·  q close %=%l/%L "
vim.opt.laststatus = 2
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

local tmux = assert(vim.env.SEELE_SCROLLBACK_TMUX, "missing tmux executable")
local socket = assert(vim.env.SEELE_SCROLLBACK_SOCKET, "missing tmux socket")
local pane = assert(vim.env.SEELE_SCROLLBACK_PANE, "missing originating pane")
local client = assert(vim.env.SEELE_SCROLLBACK_CLIENT, "missing originating client")
assert(pane:match("^%%%d+$"), "invalid originating pane")

local limit = 8 * 1024 * 1024
local chunks, size, overflow, read_error = {}, 0, false, false
local process
process = vim.system({ tmux, "-S", socket, "capture-pane", "-p", "-J", "-S", "-10000", "-t", pane }, {
  stdout = function(err, data)
    if err then
      read_error = true
    elseif data and not overflow then
      size = size + #data
      if size > limit then
        overflow = true
        chunks = {}
        if process then process:kill(15) end
      else
        chunks[#chunks + 1] = data
      end
    end
  end,
  -- Do not retain arbitrary server diagnostics, or display them as scrollback.
  stderr = false,
})
local captured = process:wait(5000)

local failure
if overflow then
  failure = "Scrollback exceeds 8 MiB; use tmux copy mode for this pane."
elseif read_error or captured.code ~= 0 then
  failure = "Cannot capture the originating tmux pane. Close this viewer and try again."
end
local data = failure or table.concat(chunks)
chunks = nil
-- capture-pane emits a final record separator; preserve every actual blank line.
if data:sub(-1) == "\n" then data = data:sub(1, -2) end
vim.bo.readonly = false
vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(data, "\n", { plain = true }))
data = nil
vim.api.nvim_buf_set_name(0, "[tmux scrollback]")
vim.bo.buftype = "nofile"
vim.bo.bufhidden = "wipe"
vim.bo.swapfile = false
vim.bo.undofile = false
vim.bo.modified = false
vim.bo.readonly = true
vim.bo.modifiable = false
vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })

local function close() vim.cmd("qall!") end
vim.keymap.set("n", "q", close, { desc = "Close scrollback" })
vim.keymap.set("n", "<Esc>", close, { desc = "Close scrollback" })
if not failure then
  vim.api.nvim_create_autocmd("TextYankPost", {
    buffer = 0,
    callback = function()
      if vim.v.event.operator ~= "y" or vim.v.event.regname == "_" then return end
      local text = table.concat(vim.v.event.regcontents, "\n")
      if vim.v.event.regtype == "V" then text = text .. "\n" end
      -- argv and stdin stay separate, including sockets/client names with shell syntax.
      -- -w uses tmux's terminal clipboard path, including over SSH.
      local result = vim.system({ tmux, "-S", socket, "load-buffer", "-w", "-t", client, "-" }, {
        stdin = text,
        stdout = false,
        stderr = false,
      }):wait(5000)
      if result.code == 0 then
        vim.schedule(close)
      else
        vim.notify("Could not copy to the originating tmux client; selection remains available.", vim.log.levels.ERROR)
      end
    end,
  })
end
