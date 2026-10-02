-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 2,
		gaps_out = 2,
		border_size = 2,
		resize_on_border = true
	},
	decoration = {
		rounding = 2,
		dim_inactive = true,
		dim_strength = 0.1,
		active_opacity = 1.0,
		shadow = {
			enabled = false,
		},
	},
	animations = {
		enabled = true
	},
	scrolling = {
		column_width = 0.49,
	},
	cursor = {
		sync_gsettings_theme = true
	}
})
