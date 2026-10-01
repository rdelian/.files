-- wallpaper.lua: background picker (fuzzy find or random), saved per theme.
-- Uses the layered `background` API: image + optional solid-color filter.
-- Call apply_to_config(config) from wezterm.lua. A pick also sets the startup image.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Brightness values also read by wezterm.lua for the base config.
M.LIGHT_BRIGHTNESS = 1.0
M.DARK_BRIGHTNESS = 0.03

local LIGHT_BRIGHTNESS = M.LIGHT_BRIGHTNESS
local DARK_BRIGHTNESS = M.DARK_BRIGHTNESS

-- Optional solid-color filter over the image, per theme (light/dark).
-- Toggle with LEADER+o. Color/opacity live here; only on/off is saved.
M.OVERLAY = {
	light = { enabled = false, color = "#ffffff", opacity = 0.8 },
	dark = { enabled = false, color = "#ffffff", opacity = 0.25 },
}
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

local function display_label(path)
	-- Relative subfolders without the root, e.g. "_whitebg > file.jpg".
	-- Longest matching root wins so overlapping roots stay short.
	local roots = isWindows and BG_ROOTS_WINDOWS or BG_ROOTS_LINUX
	local path_norm = path:gsub("\\", "/")
	local path_cmp = isWindows and path_norm:lower() or path_norm
	local best = nil
	for _, root in ipairs(roots) do
		local root_norm = root:gsub("\\", "/"):gsub("/+$", "")
		local root_cmp = isWindows and root_norm:lower() or root_norm
		if path_cmp:sub(1, #root_cmp + 1) == root_cmp .. "/" then
			local rel = path_norm:sub(#root_norm + 2)
			if best == nil or #rel < #best then
				best = rel
			end
		end
	end
	if best == nil or best == "" then
		return basename(path)
	end
	return (best:gsub("/", " > "))
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
	-- Theme only. OS matters for search paths, not for buckets.
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

local function clamp_opacity(v)
	v = tonumber(v)
	if v == nil then
		return nil
	end
	return math.min(1, math.max(0, v))
end

local function overlay_key(bucket)
	return bucket .. "_overlay"
end

-- Saved on/off for a bucket. Tolerates the old table form.
local function saved_overlay_flag(saved, bucket)
	local v = saved and saved[overlay_key(bucket)]
	if type(v) == "table" then
		return v.enabled == true
	end
	if v ~= nil then
		return v == true
	end
	local d = M.OVERLAY and M.OVERLAY[bucket]
	return type(d) == "table" and d.enabled == true
end

-- Overlay for a bucket: on/off from the saved file, color/opacity from code.
local function get_overlay(bucket, saved)
	local ov = { enabled = saved_overlay_flag(saved, bucket), color = "#ffffff", opacity = 0.25 }
	local d = M.OVERLAY and M.OVERLAY[bucket]
	if type(d) == "table" then
		if type(d.color) == "string" and d.color ~= "" then
			ov.color = d.color
		end
		local op = clamp_opacity(d.opacity)
		if op ~= nil then
			ov.opacity = op
		end
	end
	return ov
end

-- Image path for a bucket (plain-string entries).
local function saved_image_path(saved, bucket)
	local v = saved and saved[bucket]
	if type(v) == "string" then
		return v
	end
	if type(v) == "table" and type(v.path) == "string" then
		return v.path
	end
	return nil
end

local function layer_image_path(layer)
	if type(layer) ~= "table" then
		return nil
	end
	local src = layer.source
	if type(src) ~= "table" then
		return nil
	end
	if type(src.File) == "string" then
		return src.File
	end
	if type(src.File) == "table" and type(src.File.path) == "string" then
		return src.File.path
	end
	return nil
end

-- Layer 1: image with brightness. Layer 2 (optional): solid-color filter.
local function build_background(path, appearance, saved)
	if not saved_file_exists(path) then
		return nil
	end
	local bucket = bucket_for_appearance(appearance)
	local layers = {
		{ source = { File = path }, hsb = { brightness = brightness_for_appearance(appearance) } },
	}
	local ov = get_overlay(bucket, saved or load_saved_backgrounds())
	if ov.enabled then
		table.insert(layers, {
			source = { Color = ov.color },
			opacity = ov.opacity,
			width = "100%",
			height = "100%",
		})
	end
	return layers
end

-- Current live state: image path, overlay, brightness. Reads the new
-- `background` layers first, then legacy window_background_image keys.
local function live_background_state(overrides)
	overrides = overrides or {}
	local bg = overrides.background
	if type(bg) == "table" and #bg > 0 then
		local img = layer_image_path(bg[1])
		local ov = { enabled = false }
		if type(bg[2]) == "table" and type(bg[2].source) == "table" and type(bg[2].source.Color) == "string" then
			ov = { enabled = true, color = bg[2].source.Color, opacity = tonumber(bg[2].opacity) or 1.0 }
		end
		local hsb = type(bg[1]) == "table" and bg[1].hsb
		local bright = type(hsb) == "table" and hsb.brightness or nil
		return img, ov, bright
	end
	local hsb = overrides.window_background_image_hsb
	local bright = type(hsb) == "table" and hsb.brightness or nil
	return overrides.window_background_image, { enabled = false }, bright
end

local function same_overlay(a, b)
	a = a or { enabled = false }
	b = b or { enabled = false }
	if (a.enabled == true) ~= (b.enabled == true) then
		return false
	end
	if not a.enabled then
		return true
	end
	return a.color == b.color and a.opacity == b.opacity
end

-- Same theme keeps the pick, theme change loads the saved image + overlay.
local function sync_window_to_saved_theme(window)
	if not window then
		return
	end
	local appearance = window_appearance(window)
	local bucket = bucket_for_appearance(appearance)
	local desired_brightness = brightness_for_appearance(appearance)

	local saved = load_saved_backgrounds()
	local raw = saved_image_path(saved, bucket)
	local desired_image = saved_file_exists(raw) and raw or nil
	local desired_background = build_background(desired_image, appearance, saved)
	local desired_overlay = get_overlay(bucket, saved)

	local overrides = window:get_config_overrides() or {}
	local cur_image, cur_overlay, cur_brightness = live_background_state(overrides)

	if
		overrides.background == nil
		and overrides.window_background_image == nil
		and overrides.window_background_image_hsb == nil
	then
		-- Fresh window: the base config already applied it, just track state.
		wezterm.GLOBAL.bg_current = desired_image
		local k0 = last_bucket_key(window)
		if k0 then
			wezterm.GLOBAL[k0] = bucket
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

	local function apply_desired()
		overrides.background = desired_background
		overrides.window_background_image = nil
		overrides.window_background_image_hsb = nil
		wezterm.GLOBAL.bg_current = desired_image
		if k then
			wezterm.GLOBAL[k] = bucket
		end
		window:set_config_overrides(overrides)
	end

	if last_bucket ~= bucket then
		apply_desired()
		return
	end

	if
		cur_image ~= desired_image
		or cur_brightness ~= desired_brightness
		or not same_overlay(cur_overlay, desired_overlay)
		or overrides.window_background_image ~= nil
		or overrides.window_background_image_hsb ~= nil
	then
		-- The legacy-key check migrates pre-`background` overrides one last time.
		apply_desired()
	end
end

-- Runs on every config reload. Registered once.
wezterm.on("window-config-reloaded", function(window, _pane)
	pcall(sync_window_to_saved_theme, window)
end)

function M.apply_to_config(config)
	-- Startup layers from the saved file, or none if the file is missing.
	-- Uses the new `background` API (image + optional color filter) and
	-- clears the legacy window_background_image* keys (don't mix old/new).
	local saved_bgs = load_saved_backgrounds()
	pcall(wezterm.add_to_config_reload_watch_list, SAVED_BG_PATH)
	local startup_appearance = gui_appearance()
	local bucket = bucket_for_appearance(startup_appearance)
	local raw = saved_image_path(saved_bgs, bucket)
	local startup_image = saved_file_exists(raw) and raw or nil
	config.background = build_background(startup_image, startup_appearance, saved_bgs)
	config.window_background_image = nil
	config.window_background_image_hsb = nil

	local function scan_dir_recursive(root, out, depth)
		out = out or {}
		depth = depth or 0
		if depth > 99 then
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
		local seen = {}
		for _, root in ipairs(roots) do
			local found = {}
			scan_dir_recursive(root, found, 0)
			for _, path in ipairs(found) do
				if not seen[path] then
					seen[path] = true
					table.insert(images, path)
				end
			end
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
		for _, k in ipairs({ "light", "dark" }) do
			local v = tbl[k]
			if type(v) == "table" then
				v = v.path
			end
			if type(v) == "string" and v ~= "" then
				f:write(string.format("  %s = %q,\n", k, v))
			end
			-- Overlays are plain booleans.
			f:write(string.format("  %s = %s,\n", overlay_key(k), tostring(saved_overlay_flag(tbl, k))))
		end
		f:write("}\n")
		f:close()
		return true
	end

	local function save_table(tbl, what)
		local ok, err = write_saved_backgrounds(tbl)
		if not ok then
			wezterm.log_error("wallpaper persist failed (" .. what .. "): " .. tostring(err))
		end
		return ok
	end

	local function set_window_background(window, bucket, layers, image_path)
		-- Mutate (don't replace) so unrelated overrides survive; legacy keys out.
		local overrides = window:get_config_overrides() or {}
		overrides.background = layers
		overrides.window_background_image = nil
		overrides.window_background_image_hsb = nil
		window:set_config_overrides(overrides)
		wezterm.GLOBAL.bg_current = image_path
		local k = last_bucket_key(window)
		if k then
			wezterm.GLOBAL[k] = bucket
		end
	end

	local function apply_background(window, path)
		-- A pick applies live and is stored as the theme default (overlay kept).
		if not path then
			return
		end
		local appearance = window_appearance(window)
		local bucket = bucket_for_appearance(appearance)
		local saved = load_saved_backgrounds()
		set_window_background(window, bucket, build_background(path, appearance, saved), path)
		local tbl = load_saved_backgrounds()
		if tbl[bucket] ~= path then
			tbl[bucket] = path
			if save_table(tbl, "image") then
				wezterm.log_info("Wallpaper (" .. bucket .. "): " .. path)
			end
		end
	end

	local function current_background_path(window)
		local overrides = window:get_config_overrides() or {}
		local img = live_background_state(overrides)
		if img ~= nil then
			return img
		end
		if wezterm.GLOBAL.bg_current ~= nil then
			return wezterm.GLOBAL.bg_current
		end
		local cfg_bg = config.background
		if type(cfg_bg) == "table" and #cfg_bg > 0 then
			return layer_image_path(cfg_bg[1])
		end
		return config.window_background_image
	end

	local function toggle_overlay(window)
		-- Flip the color filter for the current theme, keep the image.
		if not window then
			return
		end
		local appearance = window_appearance(window)
		local bucket = bucket_for_appearance(appearance)
		local saved = load_saved_backgrounds()
		saved[overlay_key(bucket)] = not saved_overlay_flag(saved, bucket)
		if not save_table(saved, "overlay") then
			return
		end
		local path = current_background_path(window)
		set_window_background(window, bucket, build_background(path, appearance, load_saved_backgrounds()), path)
		wezterm.log_info("Wallpaper overlay (" .. bucket .. "): " .. tostring(saved[overlay_key(bucket)]))
	end

	local function random_background(window)
		local images = get_background_images()
		if #images == 0 then
			wezterm.log_warn("wallpaper: no background images found")
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
			wezterm.log_warn("wallpaper: no background images found")
			return
		end
		local choices = {}
		for idx, path in ipairs(images) do
			table.insert(choices, { id = tostring(idx), label = display_label(path) })
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
		{
			key = "o",
			desc = "Toggle color filter overlay for this theme (auto-saved)",
			run = function(window, _)
				toggle_overlay(window)
			end,
		},
	}
	M.commands = commands
end

return M
