return {
  "snacks.nvim",
  opts = {
    indent = { enabled = false },
    picker = {
      sources = {
        colorschemes = {
          layout = {
            preset = "ivy",
          },
          -- Manually force-repaint the main editor screen
          on_change = function(picker, item)
            if item then
              pcall(vim.cmd, "colorscheme " .. item.text)
            end
          end,
        },
      },
    },
  },
}
