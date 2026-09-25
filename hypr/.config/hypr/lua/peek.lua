-- Peek: liquid-glass top bar (Quickshell, ~/.config/quickshell/peek),
-- visible only while SUPER is held. SUPER state comes from evdev inside the
-- bar, not from binds here (Hyprland drops some release events).
-- SUPER+SHIFT+B switches between Peek and the regular waybar; the choice
-- persists across logins (startup.lua runs `PeekBar.sh boot`).
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod

hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(d.scriptsDir .. "/PeekBar.sh toggle"),
        { description = "toggle Peek glass bar / waybar" })

-- The glass refracts its own screen snapshot; compositor blur or layer
-- animations would fight it.
hl.layer_rule({ match = { namespace = "peek" }, no_anim = true })
