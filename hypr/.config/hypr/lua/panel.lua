-- Hold SUPER+SHIFT+P: prayer-times HUD (glass panel ~/.config/quickshell/glass/Hud.qml,
-- fed by the daemon ~/.config/hypr/panel/panel.py, autostarted from startup.lua).
-- A global shortcut: the glass shell gets both the press (show) and the
-- release (hide) straight from Hyprland.
-- Verify after editing:  hyprctl configerrors

local d = require("defaults")
local mod = d.mainMod

hl.bind(mod .. " + SHIFT + P", hl.dsp.global("glass:hud"), { description = "HUD panel (hold to show)" })
