-- Hyprland config. Each piece lives in its own file under lua/:
--
--   defaults.lua     terminal / file manager / browser, used everywhere
--   keybinds.lua     key bindings
--   startup.lua      apps launched at login
--   windowrules.lua  float / size / workspace rules per app
--   settings.lua     layout, input (keyboard, touchpad), gestures, misc
--   decorations.lua  gaps, borders, rounding, blur, shadows
--   animations.lua   animation curves and speeds
--   env.lua          environment variables
--   laptop.lua       laptop keys + touchpad device
--   monitors.lua / workspaces.lua   written by nwg-displays (scripts/nwg-displays.sh)
--   colors.lua       generated from ~/.config/palette/palette.conf (palette-apply)
--
-- After editing:  hyprctl configerrors   (Hyprland reloads on save by itself)
-- Lua API: https://wiki.hypr.land/Configuring/Start/  and  /usr/share/hypr/stubs/hl.meta.lua

-- Make ~/.config/hypr/lua/ requirable regardless of the working directory.
local HYPR = os.getenv("HOME") .. "/.config/hypr"
package.path = HYPR .. "/lua/?.lua;" .. HYPR .. "/lua/?/init.lua;" .. package.path

-- Later files win when they set the same option.
require("keybinds")
require("startup")
require("env")
require("laptop")
require("windowrules")
require("decorations")
require("animations")
require("settings")
require("monitors")
require("workspaces")
require("dojo")         -- SUPER+L → dojo TUI on workspace 7 (~/projects/dojo)
require("panel")        -- SUPER+SHIFT+P → hold-to-show HUD panel
require("peek")         -- SUPER+SHIFT+B → cycle bar: waybar / Peek / Dynamic Island
