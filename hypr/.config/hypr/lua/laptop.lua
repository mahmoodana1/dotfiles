-- Laptop-specific binds and devices (from UserConfigs/Laptops.conf).
-- https://wiki.hypr.land/Configuring/Basics/Binds/#switches

local d = require("defaults")

local mod     = d.mainMod
local scripts = d.scriptsDir

local function sh(cmd) return hl.dsp.exec_cmd(cmd) end

-- Run `hyprctl devices` to find your touchpad's name.
local TOUCHPAD_DEVICE  = "asue1209:00-04f3:319f-touchpad"
local TOUCHPAD_ENABLED = true

hl.bind("XF86KbdBrightnessDown", sh(scripts .. "/BrightnessKbd.sh --dec"), { description = "decrease keyboard brightness", repeating = true })
hl.bind("XF86KbdBrightnessUp",   sh(scripts .. "/BrightnessKbd.sh --inc"), { description = "increase keyboard brightness", repeating = true })
hl.bind("XF86MonBrightnessDown", sh(scripts .. "/Brightness.sh --dec"),    { description = "decrease monitor brightness",  repeating = true })
hl.bind("XF86MonBrightnessUp",   sh(scripts .. "/Brightness.sh --inc"),    { description = "increase monitor brightness",  repeating = true })

hl.bind("XF86Launch1", sh("rog-control-center"),   { description = "ASUS Armory Crate button" })
hl.bind("XF86Launch3", sh("asusctl led-mode -n"),  { description = "switch keyboard RGB profile" })
hl.bind("XF86Launch4", sh("asusctl profile -n"),   { description = "change fan profile" })

hl.bind("XF86TouchpadToggle", sh(scripts .. "/TouchPad.sh"), { description = "toggle touchpad" })

-- Screenshots via F6 (this laptop has no PrintScreen key)
hl.bind(mod .. " + F6",         sh(scripts .. "/ScreenShot.sh --now"),    { description = "screenshot" })
hl.bind(mod .. " + SHIFT + F6", sh(scripts .. "/ScreenShot.sh --area"),   { description = "screenshot (area)" })
hl.bind(mod .. " + CTRL + F6",  sh(scripts .. "/ScreenShot.sh --in5"),    { description = "screenshot (5s delay)" })
hl.bind(mod .. " + ALT + F6",   sh(scripts .. "/ScreenShot.sh --in10"),   { description = "screenshot (10s delay)" })
hl.bind("ALT + F6",             sh(scripts .. "/ScreenShot.sh --active"), { description = "screenshot (active window)" })

hl.device({
    name    = TOUCHPAD_DEVICE,
    enabled = TOUCHPAD_ENABLED,
})

-- Lid switch handling. Disabled, matching the old config.
-- Turns the laptop display off when the lid is closed:
-- hl.bind("switch:off:Lid Switch", sh('hyprctl keyword monitor "eDP-1, preferred, auto, 1"'), { locked = true })
-- hl.bind("switch:on:Lid Switch",  sh('hyprctl keyword monitor "eDP-1, disable"'),            { locked = true })
--
-- CAVEATS if you enable this: you may need to re-select your wallpaper (SUPER W),
-- and the main laptop monitor sometimes needs the external monitor reconnected.
-- Make sure the lid is OPEN before shutting down.
