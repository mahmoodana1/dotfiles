-- Auto-hiding "Peek" waybar: visible only while SUPER is held.
-- SUPER state is read from evdev by the daemon, not by binds here (Hyprland
-- drops some release events, which would strand the bar on screen).
-- SUPER+SHIFT+B switches between Peek and your previous waybar layout/style.
-- Daemon: ~/.config/hypr/scripts/WaybarPeek.py (autostarted from startup.lua;
-- inert unless the Peek layout is active).
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod
local ctl = d.scriptsDir .. "/WaybarPeek.sh"

hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(ctl .. " toggle"),
        { description = "toggle Peek waybar / previous layout" })

-- Frosted glass behind the bar. The Peek config's "name" gives it its own
-- layer namespace, so the old waybar layouts are unaffected.
hl.layer_rule({ match = { namespace = "peek" }, blur = true })
hl.layer_rule({ match = { namespace = "peek" }, ignore_alpha = 0 })
