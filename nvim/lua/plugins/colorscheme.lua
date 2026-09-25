local dark_colorscheme = "cyberdream"
local light_colorscheme = "cyberdream-light"

return {
  {
    "f-person/auto-dark-mode.nvim",
    lazy = true,
    event = "VeryLazy",
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.o.background = "dark"
        vim.cmd("colorscheme " .. dark_colorscheme)
      end,
      set_light_mode = function()
        vim.o.background = "light"
        vim.cmd("colorscheme " .. light_colorscheme)
      end,
    },
  },
  { "scottmckendry/cyberdream.nvim", lazy = false, priority = 1000 },
  -- { "0x-ximon/acario.nvim", name = "acario", lazy = false, priority = 1000 },
  -- { "projekt0n/github-nvim-theme", name = "github-theme", lazy = false, priority = 1000 },
  -- { "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = { style = "day" } },
  -- { "miikanissi/modus-themes.nvim", lazy = false, priority = 1000 },
  -- { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000, opts = { contrast = "hard" } },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = dark_colorscheme,
    },
  },
}
