-- dojo: SUPER+L launches (or refocuses) the dojo TUI on workspace 7, fullscreen.
-- Wire in from ~/.config/hypr/hyprland.lua with:  require("dojo")
-- (or copy these lines into keybinds.lua / windowrules.lua)
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod

-- The launcher script focuses the existing instance instead of spawning a
-- second one. The [workspace 7] exec rule places the window before it maps,
-- so there is no flicker on the current workspace.
hl.bind(mod .. " + L",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/projects/dojo/scripts/launch-dojo.sh"),
        { description = "dojo — algorithm practice (ws 7, fullscreen)" })

-- Window rules keyed on the alacritty --class flag.
hl.window_rule({ match = { class = "^(dojo)$" }, workspace = "7" })
hl.window_rule({ match = { class = "^(dojo)$" }, fullscreen = true })
