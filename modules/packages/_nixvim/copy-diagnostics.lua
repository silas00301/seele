-- Explicitly copy existing diagnostics, never source contents or server requests.
local M = {}
local max_count, max_bytes = 500, 256 * 1024
local severity_names = { "ERROR", "WARN", "INFO", "HINT" }

local function clean(text, multiline)
  text = tostring(text or ""):gsub("\r\n", "\n")
  return (text:gsub("[%c]", function(char)
    if multiline and (char == "\n" or char == "\t") then return char end
    return string.format("\\x%02X", char:byte())
  end))
end

local function overlaps(diagnostic, first, last)
  local start = diagnostic.lnum
  local finish = diagnostic.end_lnum or start
  -- Diagnostic ends are exclusive; column zero belongs to the previous line.
  if (diagnostic.end_col or 0) == 0 and finish > start then finish = finish - 1 end
  return start <= last - 1 and finish >= first - 1
end

function M.copy(reference, whole, first, last)
  first = first or vim.api.nvim_win_get_cursor(0)[1]
  last = last or first
  local _, err = reference(false, first, last)
  local function notify(message, level)
    vim.notify(message, level or vim.log.levels.WARN, { title = "Copy diagnostics" })
  end
  if err then notify(err); return end
  local selected = {}
  local bytes = 0
  for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
    if whole or overlaps(diagnostic, first, last) then
      if #selected == max_count then notify("Too many diagnostics to copy (limit: 500)"); return end
      local location, path_error = reference(false, diagnostic.lnum + 1, diagnostic.lnum + 1)
      if not location then notify(path_error); return end
      local raw_message = diagnostic.message or ""
      local raw_source = tostring(diagnostic.source or "")
      local raw_code = tostring(diagnostic.code or "")
      if #raw_message + #raw_source + #raw_code > max_bytes then
        notify("Diagnostics exceed the 256 KiB copy limit"); return
      end
      local source, code = clean(raw_source), clean(raw_code)
      local metadata = source
      if code ~= "" then metadata = metadata .. (metadata ~= "" and ":" or "") .. code end
      local severity = severity_names[diagnostic.severity] or "DIAGNOSTIC"
      local header = location .. ":" .. ((diagnostic.col or 0) + 1) .. " [" .. severity .. "]"
      if metadata ~= "" then header = header .. " (" .. metadata .. ")" end
      local message = clean(raw_message, true)
      local rendered = header .. "\n  " .. message:gsub("\n", "\n  ")
      bytes = bytes + #rendered + (#selected > 0 and 2 or 0)
      if bytes > max_bytes then notify("Diagnostics exceed the 256 KiB copy limit"); return end
      table.insert(selected, { diagnostic = diagnostic, rendered = rendered })
    end
  end
  if #selected == 0 then notify("No diagnostics in the requested lines", vim.log.levels.INFO); return end
  table.sort(selected, function(a, b)
    for _, field in ipairs({ "lnum", "col", "severity" }) do
      local av, bv = a.diagnostic[field] or 0, b.diagnostic[field] or 0
      if av ~= bv then return av < bv end
    end
    return a.rendered < b.rendered
  end)
  local lines = {}
  for _, item in ipairs(selected) do table.insert(lines, item.rendered) end
  local value = table.concat(lines, "\n\n")
  vim.fn.setreg("r", value, "v")
  local message = #selected .. (#selected == 1 and " diagnostic" or " diagnostics")
    .. ' copied to register r ("rp)'
  local level = vim.log.levels.INFO
  if vim.fn.has("clipboard") == 1 then
    if pcall(vim.fn.setreg, "+", value, "v") then
      message = message .. "; sent to clipboard provider"
    else
      message = message .. "; clipboard provider failed"
      level = vim.log.levels.WARN
    end
  else
    message = message .. "; no clipboard provider"
  end
  notify(message, level)
end

function M.setup(reference)
  vim.api.nvim_create_user_command("CopyDiagnostics", function(args)
    M.copy(reference, args.bang, args.line1, args.line2)
  end, { bang = true, range = true, desc = "Copy line diagnostics (! copies buffer)" })
  vim.keymap.set("n", "<leader>cd", function() M.copy(reference, false) end,
    { desc = "Copy line diagnostics" })
  vim.keymap.set("n", "<leader>cD", function() M.copy(reference, true) end,
    { desc = "Copy buffer diagnostics" })
end

return M
