local wezterm = require("wezterm")
local config = wezterm.config_builder()
config.automatically_reload_config = true

local wallpaper = require("wallpaper")
local appearance = wezterm.gui.get_appearance()
local isLightTheme = type(appearance) == "string" and appearance:find("Light") ~= nil
local bg_brightness = isLightTheme and wallpaper.LIGHT_BRIGHTNESS or wallpaper.DARK_BRIGHTNESS
local isWindows = wezterm.target_triple == "x86_64-pc-windows-msvc"

-- Theme / appearance only. Wallpaper images are NOT hardcoded here:
if isWindows then
	config.term = "xterm-256color"
	config.default_prog = { "pwsh", "-NoLogo" }

	-- Font
	config.font = wezterm.font("ShureTechMono Nerd Font Mono")
	config.font_size = 14

	-- Theme
	config.colors = { foreground = isLightTheme and "#2f2f2f" or "#cfcfcf" }
	config.color_scheme = isLightTheme and "Vs Code Light+ (Gogh)" or "Ir Black (Gogh)"
end

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

-- Tabline status bar (see tabline.lua).
require("tabline").apply_to_config(config)

-- Wallpaper background switching
wallpaper.apply_to_config(config)

-- All custom keybindings live here. New scripts: expose `.commands`
-- (see keybinds.lua header) and add the module to the list below.
local keybinds = require("keybinds")
keybinds.apply_to_config(config, { wallpaper })

-- LEADER+h cheatsheet + launcher for everything registered above.
require("help").apply_to_config(config)

return config
