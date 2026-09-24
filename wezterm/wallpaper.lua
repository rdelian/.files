-- wallpaper.lua: background picker (fuzzy find or random), saved per theme.
-- Call apply_to_config(config) from wezterm.lua. A pick also sets the startup image.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Brightness values also read by wezterm.lua for the base config.
M.LIGHT_BRIGHTNESS = 0.89
M.DARK_BRIGHTNESS = 0.02

local LIGHT_BRIGHTNESS = M.LIGHT_BRIGHTNESS
local DARK_BRIGHTNESS = M.DARK_BRIGHTNESS

local isWindows = wezterm.target_triple == "x86_64-pc-windows-msvc"

local BG_ROOTS_WINDOWS = { "K:/imgs/_vscode/static" }
local BG_ROOTS_LINUX = {
	wezterm.home_dir .. "/Pictures/backgrounds",
	wezterm.home_dir .. "/Pictures",
	"/home/deli/Pictures",
}

local IMAGE_EXTS = {
	jpg = true,
	jpeg = true,
	png = true,
	webp = true,
	gif = true,
	bmp = true,
}

-- Saved picks per theme, loaded at startup.
local SAVED_BG_PATH = wezterm.config_dir .. "/saved-backgrounds.lua"

math.randomseed(os.time())

local function basename(path)
	return path:match("([^/\\]+)$") or path
end

local function is_image(path)
	local ext = path:match("%.([^%.\\/]+)$")
	return ext ~= nil and IMAGE_EXTS[ext:lower()] == true
end

local function load_saved_backgrounds()
	local ok, result = pcall(dofile, SAVED_BG_PATH)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

local function saved_file_exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function is_light_appearance(appearance)
	return type(appearance) == "string" and appearance:find("Light") ~= nil
end

local function bucket_for_appearance(appearance)
	if not isWindows then
		return "linux"
	end
	return is_light_appearance(appearance) and "light" or "dark"
end

local function brightness_for_appearance(appearance)
	return is_light_appearance(appearance) and LIGHT_BRIGHTNESS or DARK_BRIGHTNESS
end

local function gui_appearance()
	local ok, a = pcall(function()
		return wezterm.gui.get_appearance()
	end)
	if ok and type(a) == "string" then
		return a
	end
	return "Dark"
end

local function window_appearance(window)
	local ok, a = pcall(function()
		return window:get_appearance()
	end)
	if ok and type(a) == "string" then
		return a
	end
	return gui_appearance()
end

local function last_bucket_key(window)
	local ok, id = pcall(function()
		return window:window_id()
	end)
	if ok and id ~= nil then
		return "bg_bucket_win_" .. tostring(id)
	end
	return nil
end

-- Same theme keeps the pick, theme change loads the saved image.
local function sync_window_to_saved_theme(window)
	if not window then
		return
	end
	local appearance = window_appearance(window)
	local bucket = bucket_for_appearance(appearance)
	local desired_brightness = brightness_for_appearance(appearance)

	local saved = load_saved_backgrounds()
	local desired_image = saved_file_exists(saved[bucket]) and saved[bucket] or nil

	local overrides = window:get_config_overrides() or {}
	local cur_image = overrides.window_background_image
	local cur_hsb = overrides.window_background_image_hsb
	local cur_brightness = type(cur_hsb) == "table" and cur_hsb.brightness or nil

	if cur_image == nil and cur_brightness == nil then
		wezterm.GLOBAL.bg_current = desired_image
		local k = last_bucket_key(window)
		if k then
			wezterm.GLOBAL[k] = bucket
		end
		return
	end

	local k = last_bucket_key(window)
	local last_bucket = k and wezterm.GLOBAL[k] or nil
	if last_bucket == nil then
		if k then
			wezterm.GLOBAL[k] = bucket
		end
		last_bucket = bucket
	end

	if last_bucket ~= bucket then
		if desired_image == nil then
			overrides.window_background_image = nil
			overrides.window_background_image_hsb = nil
		else
			overrides.window_background_image = desired_image
			overrides.window_background_image_hsb = { brightness = desired_brightness }
		end
		wezterm.GLOBAL.bg_current = desired_image
		if k then
			wezterm.GLOBAL[k] = bucket
		end
		window:set_config_overrides(overrides)
		return
	end

	if cur_brightness ~= desired_brightness then
		if cur_image == nil then
			overrides.window_background_image_hsb = nil
		else
			overrides.window_background_image_hsb = { brightness = desired_brightness }
		end
		window:set_config_overrides(overrides)
	end
end

-- Runs on every config reload. Registered once.
wezterm.on("window-config-reloaded", function(window, _pane)
	pcall(sync_window_to_saved_theme, window)
end)

local function startup_bucket()
	return bucket_for_appearance(gui_appearance())
end

function M.apply_to_config(config)
	-- Startup image from saved file, or none if the file is missing.
	local saved_bgs = load_saved_backgrounds()
	pcall(wezterm.add_to_config_reload_watch_list, SAVED_BG_PATH)
	local bucket = startup_bucket()
	if saved_file_exists(saved_bgs[bucket]) then
		config.window_background_image = saved_bgs[bucket]
	else
		config.window_background_image = nil
	end

	local function scan_dir_recursive(root, out, depth)
		out = out or {}
		depth = depth or 0
		if depth > 4 then
			return out
		end
		local ok, entries = pcall(wezterm.read_dir, root)
		if not ok or not entries then
			return out
		end
		for _, entry in ipairs(entries) do
			if is_image(entry) then
				table.insert(out, entry)
			else
				local dir_ok = pcall(wezterm.read_dir, entry)
				if dir_ok then
					scan_dir_recursive(entry, out, depth + 1)
				end
			end
		end
		return out
	end

	local function get_background_images()
		local roots = isWindows and BG_ROOTS_WINDOWS or BG_ROOTS_LINUX
		local images = {}
		for _, root in ipairs(roots) do
			scan_dir_recursive(root, images, 0)
		end
		table.sort(images)
		return images
	end

	local function write_saved_backgrounds(tbl)
		local f, err = io.open(SAVED_BG_PATH, "w")
		if not f then
			return nil, err
		end
		f:write("return {\n")
		for _, k in ipairs({ "light", "dark", "linux" }) do
			if tbl[k] and tbl[k] ~= "" then
				f:write(string.format("  %s = %q,\n", k, tbl[k]))
			end
		end
		f:write("}\n")
		f:close()
		return true
	end

	local function apply_background(window, path)
		-- A pick applies live and is stored as the theme default.
		if not path then
			return
		end
		local appearance = window_appearance(window)
		local bucket = bucket_for_appearance(appearance)
		window:set_config_overrides({
			window_background_image = path,
			window_background_image_hsb = { brightness = brightness_for_appearance(appearance) },
		})
		wezterm.GLOBAL.bg_current = path
		local k = last_bucket_key(window)
		if k then
			wezterm.GLOBAL[k] = bucket
		end
		local tbl = load_saved_backgrounds()
		if tbl[bucket] ~= path then
			tbl[bucket] = path
			local ok, err = write_saved_backgrounds(tbl)
			if not ok then
				wezterm.log_error("wallpaper persist failed: " .. tostring(err))
				window:toast_notification("wezterm", "Persist failed: " .. tostring(err), nil, 4000)
			else
				wezterm.log_info("Wallpaper (" .. bucket .. "): " .. path)
			end
		end
	end

	local function current_background_path(window)
		local overrides = window:get_config_overrides() or {}
		return overrides.window_background_image or wezterm.GLOBAL.bg_current or config.window_background_image
	end

	local function random_background(window)
		local images = get_background_images()
		if #images == 0 then
			window:toast_notification("wezterm", "No background images found", nil, 2000)
			return
		end
		local current = current_background_path(window)
		local new_idx = math.random(#images)
		if #images > 1 and images[new_idx] == current then
			new_idx = (new_idx % #images) + 1
		end
		apply_background(window, images[new_idx])
	end

	local function pick_background(window, pane)
		local images = get_background_images()
		if #images == 0 then
			window:toast_notification("wezterm", "No background images found", nil, 2000)
			return
		end
		local choices = {}
		for idx, path in ipairs(images) do
			table.insert(choices, { id = tostring(idx), label = basename(path) })
		end
		window:perform_action(
			act.InputSelector({
				title = "Select Background",
				description = "Fuzzy-find background (/ to search, Enter to apply, Esc to cancel)",
				fuzzy = true,
				choices = choices,
				action = wezterm.action_callback(function(inner_window, _, id, _)
					if not id then
						return
					end
					local path = images[tonumber(id)]
					if path then
						apply_background(inner_window, path)
					end
				end),
			}),
			pane
		)
	end

	-- LEADER keys exposed for keybinds.lua and help.lua.
	local commands = {
		{
			key = "b",
			desc = "Fuzzy-find background by filename and apply (auto-saved)",
			run = pick_background,
		},
		{
			key = "r",
			desc = "Random background (auto-saved for this theme)",
			run = function(window, _)
				random_background(window)
			end,
		},
	}
	M.commands = commands
end

return M
