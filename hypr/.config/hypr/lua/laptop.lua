-- Laptop-only binds and devices.
-- https://wiki.hypr.land/Configuring/Basics/Binds/#switches

local d = require("defaults")

local mod     = d.mainMod
local s       = d.scripts

local function sh(cmd) return hl.dsp.exec_cmd(cmd) end

-- Run `hyprctl devices` to find your touchpad's name.
local TOUCHPAD_DEVICE  = "etps/2-elantech-touchpad"   -- also set in scripts/touchpad.sh
local TOUCHPAD_ENABLED = true

hl.bind("XF86KbdBrightnessDown", sh(s .. "/brightness.sh kbd-down"), { description = "decrease keyboard brightness", repeating = true })
hl.bind("XF86KbdBrightnessUp",   sh(s .. "/brightness.sh kbd-up"), { description = "increase keyboard brightness", repeating = true })
hl.bind("XF86MonBrightnessDown", sh(s .. "/brightness.sh down"),    { description = "decrease monitor brightness",  repeating = true })
hl.bind("XF86MonBrightnessUp",   sh(s .. "/brightness.sh up"),    { description = "increase monitor brightness",  repeating = true })

hl.bind("XF86Launch1", sh("rog-control-center"),   { description = "ASUS Armory Crate button" })
hl.bind("XF86Launch3", sh("asusctl led-mode -n"),  { description = "switch keyboard RGB profile" })
hl.bind("XF86Launch4", sh("asusctl profile -n"),   { description = "change fan profile" })

hl.bind("XF86TouchpadToggle", sh(s .. "/touchpad.sh"), { description = "toggle touchpad" })

-- Screenshots via F6 (this laptop has no PrintScreen key)
hl.bind(mod .. " + F6",         sh(s .. "/screenshot.sh now"),    { description = "screenshot" })
hl.bind(mod .. " + SHIFT + F6", sh(s .. "/screenshot.sh area"),   { description = "screenshot (area)" })
hl.bind(mod .. " + CTRL + F6",  sh(s .. "/screenshot.sh in5"),    { description = "screenshot (5s delay)" })
hl.bind(mod .. " + ALT + F6",   sh(s .. "/screenshot.sh in10"),   { description = "screenshot (10s delay)" })
hl.bind("ALT + F6",             sh(s .. "/screenshot.sh window"), { description = "screenshot (active window)" })

hl.device({
    name    = TOUCHPAD_DEVICE,
    enabled = TOUCHPAD_ENABLED,
})

-- Lid switch handling. Disabled, matching the old config.
-- Turns the laptop display off when the lid is closed:
-- hl.bind("switch:off:Lid Switch", sh('hyprctl keyword monitor "eDP-1, preferred, auto, 1"'), { locked = true })
-- hl.bind("switch:on:Lid Switch",  sh('hyprctl keyword monitor "eDP-1, disable"'),            { locked = true })
--
