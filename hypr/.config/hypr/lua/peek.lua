-- Auto-hiding "Peek" waybar.
-- Hold SUPER to peek; the bar also flashes on workspace change and appears
-- when the mouse is pushed to the top edge. SUPER+SHIFT+B switches between
-- Peek and your previous waybar layout/style.
-- Daemon: ~/.config/hypr/scripts/WaybarPeek.py (autostarted from startup.lua;
-- inert unless the Peek layout is active).
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod
local ctl = d.scriptsDir .. "/WaybarPeek.sh"

-- non_consuming: SUPER must still reach every SUPER+key chord.
hl.bind("Super_L", hl.dsp.exec_cmd(ctl .. " press"),
        { description = "peek waybar (hold SUPER)", non_consuming = true })

hl.bind(mod .. " + Super_L", hl.dsp.exec_cmd(ctl .. " release"),
        { description = "peek waybar (hide on release)", release = true, non_consuming = true })

hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(ctl .. " toggle"),
        { description = "toggle Peek waybar / previous layout" })
