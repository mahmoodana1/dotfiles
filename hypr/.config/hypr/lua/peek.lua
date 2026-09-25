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

-- Live frost behind the glass interior. ignore_alpha sits between the drop
-- shadow's max alpha (~0.14) and the interior's (>= 0.22, Glass.qml `tint`),
-- so only the glass is blurred. Layer animations would fight the bar's own.
hl.layer_rule({ match = { namespace = "peek" }, no_anim = true })
hl.layer_rule({ match = { namespace = "peek" }, blur = true })
hl.layer_rule({ match = { namespace = "peek" }, ignore_alpha = 0.16 })
