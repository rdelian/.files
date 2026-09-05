-- Generic: just allow luau_lsp to start.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        luau_lsp = {},
      },
    },
  },
}
