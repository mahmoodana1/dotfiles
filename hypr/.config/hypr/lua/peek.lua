-- Peek: liquid-glass top bar (Quickshell, ~/.config/quickshell/peek),
-- visible only while SUPER is held. SUPER state comes from evdev inside the
-- bar, not from binds here (Hyprland drops some release events).
-- SUPER+SHIFT+B cycles waybar -> Peek -> Dynamic Island (quickshell/island);
-- the choice persists across logins (startup.lua runs `bar.sh boot`).
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod

hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(d.scripts .. "/bar.sh cycle"),
        { description = "cycle top bar: waybar / Peek / Dynamic Island" })

-- Clear glass: no compositor blur (the interior is see-through; glass.frag
-- draws the refracted rim). Layer animations would fight the bars' own.
hl.layer_rule({ match = { namespace = "peek" }, no_anim = true })

-- Halo island (~/.config/quickshell/island): a frosted pill, so blur behind
-- its body; ignore_alpha skips the clear rest of the layer (the pill's tint
-- stays above 0.3 everywhere, see Look.qml).
hl.layer_rule({ match = { namespace = "island" }, no_anim = true })
hl.layer_rule({ match = { namespace = "island" }, blur = true })
hl.layer_rule({ match = { namespace = "island" }, ignore_alpha = 0.3 })
