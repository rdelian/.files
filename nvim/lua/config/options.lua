-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Allow project-local `.nvim.lua` (runs on trust prompt)
vim.opt.exrc = true
vim.g.root_spec = { "cwd" }
vim.opt.list = true
vim.opt.listchars = {
  tab = " ",
  space = " ",
  nbsp = "␣",
  trail = "•",
  extends = "",
  precedes = "",
}

-- Use hard tabs for Go files
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "lua", "luau", "cpp" },
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})
