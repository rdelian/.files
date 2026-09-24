-- keybinds.lua: register LEADER keys in one place.
-- Entry: { key, desc, run(window, pane), mods (default LEADER), key_label }.
-- Modules provide M.commands, wired via apply_to_config(config, modules).
local wezterm = require("wezterm")

local M = {}

-- Cleared on each apply because reload re-runs config but keeps this module loaded.
M.all = {}

-- Used only if config.leader is not set.
local DEFAULT_LEADER = { key = "Space", mods = "CTRL|SHIFT", timeout_milliseconds = 2000 }

local function mods_of(cmd)
	return cmd.mods or "LEADER"
end

local function binding_id(cmd)
	return mods_of(cmd) .. "+" .. cmd.key
end

function M.add_binding(config, cmd)
	config.keys = config.keys or {}
	for _, existing in ipairs(config.keys) do
		if existing.key == cmd.key and (existing.mods or "") == mods_of(cmd) then
			wezterm.log_warn("keybinds: duplicate binding " .. binding_id(cmd) .. " ignored (" .. cmd.desc .. ")")
			return false
		end
	end
	table.insert(M.all, cmd)
	local c = cmd
	table.insert(config.keys, {
		key = c.key,
		mods = mods_of(c),
		action = wezterm.action_callback(function(window, pane)
			c.run(window, pane)
		end),
	})
	return true
end

function M.apply_to_config(config, modules)
	M.all = {}
	if not config.leader then
		config.leader = DEFAULT_LEADER
	end
	config.keys = config.keys or {}
	for _, mod in ipairs(modules or {}) do
		if type(mod) == "table" and type(mod.commands) == "table" then
			for _, cmd in ipairs(mod.commands) do
				M.add_binding(config, cmd)
			end
		end
	end
end

return M
