-- Hyprland configuration (Lua format).
-- Migrated from the legacy .conf format, which Hyprland removes in 0.57.
-- Original files are preserved under ~/.config/hypr/legacy-conf/
--
-- https://wiki.hypr.land/Configuring/Start/

-- Make ~/.config/hypr/lua/ requirable regardless of the working directory.
local HYPR = os.getenv("HOME") .. "/.config/hypr"
package.path = HYPR .. "/lua/?.lua;" .. HYPR .. "/lua/?/init.lua;" .. package.path

-- Load order mirrors the old source= order, because later values win.
require("keybinds")     -- was configs/Keybinds.conf + UserConfigs/UserKeybinds.conf
require("startup")      -- was configs/Startup_Apps.conf + UserConfigs/Startup_Apps.conf
require("env")          -- was UserConfigs/ENVariables.conf (+ hyprland.conf tail)
require("laptop")       -- was UserConfigs/Laptops.conf + LaptopDisplay.conf
require("windowrules")  -- was configs/WindowRules.conf + UserConfigs/WindowRules.conf
require("decorations")  -- was UserConfigs/UserDecorations.conf
require("animations")   -- was UserConfigs/UserAnimations.conf
require("settings")     -- was UserConfigs/UserSettings.conf (+ hyprland.conf input tail)
require("monitors")     -- was monitors.conf
require("workspaces")   -- was workspaces.conf
require("dojo")         -- SUPER+L → dojo TUI on workspace 7 (~/projects/dojo)
