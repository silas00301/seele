local report = os.getenv("SEELE_FAILURE_REPORT")

if report == nil or report == "" then
  vim.api.nvim_err_writeln("SEELE_FAILURE_REPORT is not set")
  vim.cmd("cq")
  return
end

local handle, error_message = io.open(report, "rb")
if handle == nil then
  vim.api.nvim_err_writeln("Could not open failure report: " .. tostring(error_message))
  vim.cmd("cq")
  return
end

local contents = handle:read("*a")
handle:close()

local lines = vim.split(contents, "\n", { plain = true })
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buffer, "Seele failure report")
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
vim.bo[buffer].buftype = "nofile"
vim.bo[buffer].bufhidden = "wipe"
vim.bo[buffer].swapfile = false
vim.bo[buffer].modifiable = false
vim.bo[buffer].readonly = true
vim.bo[buffer].filetype = "log"
vim.api.nvim_set_current_buf(buffer)

vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt.title = true
vim.opt.titlestring = "System failure report"

vim.keymap.set("n", "q", "<cmd>quit<cr>", { buffer = buffer, silent = true })
vim.keymap.set("n", "<Esc>", "<cmd>quit<cr>", { buffer = buffer, silent = true })
