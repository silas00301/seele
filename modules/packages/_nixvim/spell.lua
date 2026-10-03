-- Prose buffers are spell checked in English and German.
--
-- The German spell file is built from source into this configuration's own
-- runtime path, so Neovim never offers to download one from the Vim mirror.
-- Source code is left alone: a flagged identifier is noise, not a typo.
local M = {}

-- Filetypes written for people to read. Inside them, Treesitter queries and
-- syntax files still decide what counts as prose, so fenced code, URLs,
-- change IDs and the file lists Git and Jujutsu generate are not flagged.
M.filetypes = {
  "gitcommit",
  "jjdescription",
  "mail",
  "markdown",
  "text",
}

function M.setup()
  -- The two languages Brave already checks. A spelling that is correct on
  -- the other side of a border is marked regional rather than wrong.
  vim.opt.spelllang = { "en_us", "de_de" }

  -- `zg` writes words the user taught the editor, which is personal data
  -- rather than configuration. Name the file instead of letting Neovim pick
  -- the first writable runtime directory, which differs between a host and a
  -- portable run and is never the read-only store path this config lives in.
  -- Neovim creates the file but not its directory, so `zg` would fail with
  -- E484 on a fresh machine. The list can hold people's names, so the
  -- directory is created private, like the undo history.
  local directory = vim.fn.stdpath("data") .. "/spell"
  pcall(vim.fn.mkdir, directory, "p", tonumber("700", 8))
  vim.opt.spellfile = directory .. "/personal.utf-8.add"

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("seele_prose_spell", { clear = true }),
    pattern = M.filetypes,
    callback = function()
      vim.opt_local.spell = true
    end,
  })
end

return M
