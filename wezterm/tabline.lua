-- tabline.lua – tabline.wez plugin setup.
-- Self-contained: `require("tabline").apply_to_config(config)` from wezterm.lua.
local wezterm = require("wezterm")

local M = {}

function M.apply_to_config(config)
	local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
	tabline.setup({
		options = {
			theme = "Catppuccin Mocha",
			tabs_enabled = true,
			section_separators = {
				left = wezterm.nerdfonts.ple_upper_left_triangle,
				right = wezterm.nerdfonts.ple_upper_right_triangle,
			},
			component_separators = {
				left = wezterm.nerdfonts.pl_left_soft_divider,
				right = wezterm.nerdfonts.pl_right_soft_divider,
			},
			tab_separators = {
				right = wezterm.nerdfonts.ple_lower_right_triangle,
				left = wezterm.nerdfonts.ple_lower_left_triangle,
			},
		},
		sections = {
			tabline_a = { "datetime" },
			tabline_b = { "🪐" },
			tabline_c = {},
			tab_active = { { "process", padding = 1 } },
			tab_inactive = { { "process", padding = 1 } },
			-- tabline_x = { { "cpu", use_pwsh = true } },
			tabline_x = { "hostname" },
			tabline_y = {},
			tabline_z = { "domain" },
		},
		extensions = {},
	})
	tabline.apply_to_config(config)
end

return M
