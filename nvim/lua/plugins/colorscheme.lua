return {
  -- =================================================
  -- 1. DOWNLOAD & DOWNLOAD-TIME CONFIG FOR ALL THEMES
  -- =================================================
  { "0x-ximon/acario.nvim", name = "acario", lazy = false, priority = 1000 },
  { "projekt0n/github-nvim-theme", name = "github-theme", lazy = false, priority = 1000 },
  { "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = { style = "day" } },
  { "miikanissi/modus-themes.nvim", lazy = false, priority = 1000 },
  { "scottmckendry/cyberdream.nvim", lazy = false, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000, opts = { contrast = "hard" } },
  -- ========================
  -- 2. LAZYVIM STARTUP SETUP
  -- ========================
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "cyberdream",
      light_colorscheme = "gruvbox",
    },
  },
}
