return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Map the luau filetype to use the stylua formatter
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.luau = { "stylua" }
    end,
  },
}
