do
  local function configure()
    -- The host opts in; every other editor keeps its configured colorscheme.
    local state = vim.env.SEELE_THEME_STATE
    if not state or state == "" then return end
    local keys = { "base00", "base01", "base02", "base03", "base04", "base05", "base06", "base07",
      "base08", "base09", "base0A", "base0B", "base0C", "base0D", "base0E", "base0F" }
    local current
    local function apply()
      local file = io.open(state .. "/selection.json", "r")
      if not file then return end
      local bytes = file:read(32769)
      file:close()
      if not bytes or #bytes > 32768 then return end
      local ok, theme = pcall(vim.json.decode, bytes)
      if not ok or type(theme) ~= "table" or theme.version ~= 2 then return end
      if theme.mode ~= "light" and theme.mode ~= "dark" then return end
      if type(theme.palette) ~= "table" then return end
      local palette, values = {}, { theme.mode }
      local count = 0
      for _ in pairs(theme.palette) do count = count + 1 end
      if count ~= #keys then return end
      for _, key in ipairs(keys) do
        local color = theme.palette[key]
        if type(color) ~= "string" or not color:match("^#%x%x%x%x%x%x$") then return end
        palette[key] = color
        table.insert(values, color)
      end
      -- Content identity also catches palette edits under an unchanged theme ID.
      local identity = table.concat(values, ";")
      if current == identity then return end
      local loaded, base16 = pcall(require, "mini.base16")
      if not loaded then return end
      vim.g.colors_name = nil
      vim.o.background = theme.mode
      vim.cmd("highlight clear")
      base16.setup({ palette = palette })
      -- Retain Seele's transparent editor while preserving generated foregrounds.
      for _, name in ipairs({ "Normal", "NormalNC", "NonText", "SignColumn", "LineNr" }) do
        local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
        highlight.bg = nil
        vim.api.nvim_set_hl(0, name, highlight)
      end
      vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "seele", modeline = false })
      current = identity
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
  end
  configure()
end
