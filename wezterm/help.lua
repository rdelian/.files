-- help.lua: LEADER+h picker that lists and runs entries in keybinds.all.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.apply_to_config(config)
	local keybinds = require("keybinds")

	local function show_help(window, pane)
		local choices = {}
		for _, cmd in ipairs(keybinds.all) do
			local label = cmd.key_label or cmd.key
			local mods = cmd.mods or "LEADER"
			table.insert(choices, {
				id = mods .. "+" .. cmd.key,
				label = mods .. " + " .. label .. " - " .. cmd.desc,
			})
		end
		window:perform_action(
			act.InputSelector({
				title = "Custom commands",
				description = "Your shortcuts (fuzzy search, Enter to run, Esc to close)",
				fuzzy = true,
				choices = choices,
				action = wezterm.action_callback(function(inner_window, inner_pane, id, _)
					if not id then
						return
					end
					for _, cmd in ipairs(keybinds.all) do
						local mods = cmd.mods or "LEADER"
						if mods .. "+" .. cmd.key == id and cmd.run then
							cmd.run(inner_window, inner_pane)
							return
						end
					end
				end),
			}),
			pane
		)
	end

	keybinds.add_binding(config, {
		key = "h",
		desc = "Show this overview of custom commands",
		run = show_help,
	})
end

return M
