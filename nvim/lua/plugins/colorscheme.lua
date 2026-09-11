return {
  -- =================================================
  -- 1. DOWNLOAD & DOWNLOAD-TIME CONFIG FOR ALL THEMES
  -- =================================================
  { "0x-ximon/acario.nvim", name = "acario", lazy = false, priority = 1000 },
  { "projekt0n/github-nvim-theme", name = "github-theme", lazy = false, priority = 1000 },
  -- ========================
  -- 2. LAZYVIM STARTUP SETUP
  -- ========================
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "acario_dark",
    },
  },
}
