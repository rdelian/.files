local wezterm = require("wezterm")
local config = wezterm.config_builder()
config.automatically_reload_config = true

local bg_brightness = 0.05
local isWindows = wezterm.target_triple == "x86_64-pc-windows-msvc"

--=======--
--==  ==--
--=======--
if isWindows then
	bg_brightness = 0.07

	config.default_prog = { "pwsh", "-NoLogo" }
	-- fonts
	config.font = wezterm.font("ShureTechMono Nerd Font Mono")
	config.font_size = 16
	-- bg
	config.window_background_image = "K:/imgs/triage/Mechanic Corpse ThinkPad Wallpaper.png"
else
	config.window_background_image = "/home/deli/sGchLE5.jpeg"
end

config.color_scheme = "Monokai Remastered"
config.default_cursor_style = "BlinkingBlock"

config.front_end = "WebGpu"
config.animation_fps = 240
config.max_fps = 240
config.cursor_blink_rate = 300

config.window_background_image_hsb = { brightness = bg_brightness }
config.inactive_pane_hsb = { brightness = 0.8 }
config.window_background_opacity = 1.0
config.text_background_opacity = 1.0

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
-- config.tab_bar_at_bottom = true

config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.window_close_confirmation = "NeverPrompt"

--====================--
--== TABLINE Plugin ==--
--====================--
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
		tabline_c = { "" },
		tab_active = { "", { "cwd", padding = 1 } },
		tab_inactive = { "", { "process", padding = { left = 0, right = 0 } } },
		tabline_x = { "", { "cpu", use_pwsh = isWindows } },
		tabline_y = { "" },
		tabline_z = { "domain" },
	},
	extensions = {},
})
tabline.apply_to_config(config)

return config
