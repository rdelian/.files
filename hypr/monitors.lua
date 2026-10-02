-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "highrr", position = "auto", scale = omarchy_monitor_scale })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, transform = 1 })
