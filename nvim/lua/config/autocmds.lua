-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Forcibly clear background highlights on colorscheme load

local function clear_bg()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "FoldColumn",
    "NeoTreeNormal",
    "NeoTreeNormalNC",
    "NeoTreeEndOfBuffer",
    "StatusLine",
    "StatusLineNC",
    "WinSeparator",
    "VertSplit",
  }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
  end
end

-- Re-apply every single time you navigate buffers or change themes
vim.api.nvim_create_autocmd({ "ColorScheme", "BufEnter", "WinEnter" }, {
  pattern = "*",
  callback = clear_bg,
})

-- Force immediate evaluation
clear_bg()
