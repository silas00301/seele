local M = {}

function M.trim(first, last, force)
  if vim.bo.buftype ~= "" or vim.bo.readonly or not vim.bo.modifiable then
    vim.notify("Whitespace cleanup needs an editable file buffer", vim.log.levels.WARN)
    return
  end

  local markdown = vim.bo.filetype:match("^markdown") or vim.bo.filetype == "mdx"
  local edits, preserved = {}, 0
  for offset, line in ipairs(vim.api.nvim_buf_get_lines(0, first - 1, last, true)) do
    local start = line:find("[ \t]+$")
    if start then
      -- Conservatively retain possible hard breaks, including inside code fences.
      if markdown and not force and line:find("[^ \t]") and line:match("  $") then
        preserved = preserved + 1
      else
        edits[#edits + 1] = { first + offset - 2, start - 1, #line }
      end
    end
  end

  local view = vim.fn.winsaveview()
  for index, edit in ipairs(edits) do
    if index > 1 then
      vim.cmd.undojoin()
    end
    -- Edit only the suffix: keep marks/extmarks in the unchanged text intact.
    vim.api.nvim_buf_set_text(0, edit[1], edit[2], edit[1], edit[3], {})
  end
  vim.fn.winrestview(view)
  local message = ("Trimmed trailing whitespace on %d line(s)"):format(#edits)
  if preserved > 0 then
    message = message .. ("; kept %d Markdown hard break(s), use :TrimWhitespace! to remove"):format(preserved)
  end
  vim.notify(message)
end

function M.setup()
  vim.api.nvim_create_user_command("TrimWhitespace", function(opts)
    M.trim(opts.line1, opts.line2, opts.bang)
  end, {
    range = "%",
    bang = true,
    desc = "Trim trailing spaces and tabs (! includes Markdown hard breaks)",
  })
  vim.keymap.set("n", "<leader>cw", "<cmd>TrimWhitespace<CR>", { desc = "Trim buffer trailing whitespace" })
  vim.keymap.set("x", "<leader>cw", ":TrimWhitespace<CR>", { desc = "Trim selected lines' trailing whitespace" })
end

return M
