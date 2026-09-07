local wezterm = require("wezterm")
local config = wezterm.config_builder()

local bg_brightness = 0.05

--=======--
--==  ==--
--=======--
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	bg_brightness = 0.10

	config.default_prog = { "pwsh", "-NoLogo" }
	-- fonts
	config.font = wezterm.font("FiraCode Nerd Font Mono")
	config.font_size = 12
	-- bg
	config.window_background_image = "K:/imgs/_vscode/static/_WhiteBg/desktop anime wallpaper.png"
else
	config.window_background_image = "/home/deli/sGchLE5.jpeg"
end

config.color_scheme = "Monokai Remastered"

config.window_background_image_hsb = {
	brightness = bg_brightness,
	hue = 1.0,
	saturation = 1.0,
}

config.inactive_pane_hsb = {
	brightness = 0.8,
}

config.window_background_opacity = 1.0
config.text_background_opacity = 1.0

config.hide_tab_bar_if_only_one_tab = true
-- config.tab_bar_at_bottom = true

return config
