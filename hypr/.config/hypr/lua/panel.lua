-- Hold-to-show HUD panel.
-- SUPER+SHIFT+P shows a centered overlay while held; releasing hides it.
-- Daemon: ~/.config/hypr/panel/panel.py (autostarted from startup.lua)
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod
local ctl = os.getenv("HOME") .. "/.config/hypr/panel/panelctl.sh"

-- `repeating` makes the press bind re-fire at input:repeat_rate while held,
-- which feeds the daemon's watchdog. Measured 2026-08-29: Hyprland drops ~9%
-- of release events (fast or odd-ordered releases), which without the watchdog
-- strands the overlay on screen — once for 4.1s during testing. The release
-- bind below is the fast path; the heartbeat is the guarantee.
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(ctl .. " show"),
        { description = "HUD panel (hold to show)", repeating = true })

hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(ctl .. " hide"),
        { description = "HUD panel (hide on release)", release = true })

-- Compositor blur behind the card, mirroring the rofi rules in windowrules.lua.
hl.layer_rule({ match = { namespace = "hudpanel" }, blur = true })
hl.layer_rule({ match = { namespace = "hudpanel" }, ignore_alpha = 0 })
