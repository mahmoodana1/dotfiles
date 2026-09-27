-- Keybinds. https://wiki.hypr.land/Configuring/Basics/Binds/
--
-- Add a bind:   hl.bind(mod .. " + KEY", <action>, { description = "..." })
--   run a command:        sh("some-command")
--   run a hypr script:    sh(s .. "/name.sh arg")     (scripts live in ~/.config/hypr/scripts)
-- The description shows up in SUPER+H (shortcut viewer).
-- Check for mistakes after editing:  hyprctl configerrors
--
-- Also bound elsewhere: laptop.lua (brightness, F6 screenshots), dojo.lua (SUPER+L),
-- panel.lua (SUPER+SHIFT+P), peek.lua (SUPER+SHIFT+B).

local d = require("defaults")

local mod  = d.mainMod
local s    = d.scripts
local term = d.terminal
-- Glass panels (~/.config/quickshell/glass) take their keys as global shortcuts:
-- the keypress goes straight to the running shell, no process per press.
local function glass(name) return hl.dsp.global("glass:" .. name) end

local function sh(cmd)
    return hl.dsp.exec_cmd(cmd)
end

----------------------------------------------------------------------
-- APPS
----------------------------------------------------------------------

hl.bind(mod .. " + Return", sh(term), { description = "terminal" })
hl.bind(mod .. " + SHIFT + Return", sh(term .. " --class alacritty-float"), { description = "floating terminal" })
hl.bind(mod .. " + E", sh(d.fileManager), { description = "file manager" })
hl.bind(mod .. " + B", sh(d.browser), { description = "browser" })
hl.bind(mod .. " + D", glass("launcher"), { description = "app launcher" })
hl.bind(mod .. " + CTRL + S", glass("windows"), { description = "window switcher" })
hl.bind(mod .. " + F", sh(term .. " -e bash -lc " .. d.home .. "/.local/bin/tmux-sessionizer"), { description = "tmux sessionizer (pick project)" })
hl.bind(mod .. " + A", sh(s .. "/openclaw-tui.sh"), { description = "OpenClaw TUI (ws 5)" })
hl.bind(mod .. " + T", sh(s .. "/taskvim.sh"), { description = "taskvim (ws 8)" })
hl.bind(mod .. " + H", glass("shortcuts"), { description = "shortcut viewer" })

----------------------------------------------------------------------
-- SESSION
----------------------------------------------------------------------

-- SUPER+Q closes an open glass panel or floating island panel first (they
-- hold the keyboard while open: interactivity ~= 0), otherwise the window.
local function panel_open(ns)
    for _, l in ipairs(hl.get_layers({ namespace = ns })) do
        if l.mapped and l.interactivity ~= 0 then return true end
    end
    return false
end
hl.bind(mod .. " + Q", function()
    if panel_open("glass") then hl.dispatch(hl.dsp.global("glass:close"))
    elseif panel_open("island-float") then hl.dispatch(hl.dsp.global("island:close"))
    else hl.dispatch(hl.dsp.window.close()) end
end, { description = "close panel or window" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "force-kill window" })
hl.bind("CTRL + ALT + L", sh("loginctl lock-session"), { description = "lock screen" })
hl.bind("CTRL + ALT + P", glass("power"), { description = "power menu" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exit(), { description = "exit Hyprland" })
hl.bind(mod .. " + SHIFT + N", sh("swaync-client -t -sw"), { description = "notification center" })

----------------------------------------------------------------------
-- WINDOWS
----------------------------------------------------------------------

hl.bind(mod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "float / tile window" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "fullscreen" })
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen(1), { description = "maximize" })
hl.bind(mod .. " + CTRL + O", sh("hyprctl setprop active opaque toggle"), { description = "toggle window opacity" })
hl.bind("ALT + tab", hl.dsp.window.cycle_next(), { description = "cycle windows" })
hl.bind("ALT + tab", hl.dsp.window.bring_to_top(), { description = "bring active to top" })

-- Arrow keys: focus / move / swap / resize
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }), { description = "focus " .. dir })
    hl.bind(mod .. " + CTRL + " .. dir, hl.dsp.window.move({ direction = dir }), { description = "move window " .. dir })
    hl.bind(mod .. " + ALT + " .. dir, hl.dsp.window.swap({ direction = dir }), { description = "swap window " .. dir })
end

local resize = { left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 } }
for dir, xy in pairs(resize) do
    hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.resize({ x = xy[1], y = xy[2], relative = true }),
        { description = "resize " .. dir, repeating = true })
end

-- Mouse: SUPER+drag moves, SUPER+right-drag resizes
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { description = "move window", mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { description = "resize window", mouse = true })

-- Layout (dwindle; master binds work if you switch general.layout in settings.lua)
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("togglesplit"), { description = "toggle split direction" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "pseudo-tile" })
hl.bind(mod .. " + M", hl.dsp.layout("splitratio 0.3"), { description = "grow split by 0.3" })
hl.bind(mod .. " + I", hl.dsp.layout("addmaster"), { description = "add master" })
hl.bind(mod .. " + CTRL + D", hl.dsp.layout("removemaster"), { description = "remove master" })
hl.bind(mod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"), { description = "swap with master" })

-- Groups (tabbed windows)
hl.bind(mod .. " + G", hl.dsp.group.toggle(), { description = "toggle group" })
hl.bind(mod .. " + CTRL + tab", hl.dsp.group.next(), { description = "next window in group" })

----------------------------------------------------------------------
-- WORKSPACES
----------------------------------------------------------------------

-- SUPER+1..0 go to, SHIFT moves the window there, CTRL moves it silently.
-- Key codes (code:10 = 1 ... code:19 = 0) so these survive layout switches (us/ara).
for i = 1, 10 do
    local key = "code:" .. (9 + i)
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "workspace " .. i })
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "move to workspace " .. i })
    hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, silent = true }), { description = "move silently to workspace " .. i })
end

hl.bind(mod .. " + tab", hl.dsp.focus({ workspace = "m+1" }), { description = "next workspace" })
hl.bind(mod .. " + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }), { description = "previous workspace" })
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })

hl.bind(mod .. " + SHIFT + bracketleft", hl.dsp.window.move({ workspace = "-1" }), { description = "move to previous workspace" })
hl.bind(mod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }), { description = "move to next workspace" })
hl.bind(mod .. " + CTRL + bracketleft", hl.dsp.window.move({ workspace = "-1", silent = true }), { description = "move silently to previous workspace" })
hl.bind(mod .. " + CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", silent = true }), { description = "move silently to next workspace" })

-- Scratchpad
hl.bind(mod .. " + U", hl.dsp.workspace.toggle_special(), { description = "toggle scratchpad" })
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special" }), { description = "move to scratchpad" })

-- Move the whole workspace to another monitor
hl.bind(mod .. " + CTRL + F9", hl.dsp.workspace.move({ monitor = "left" }), { description = "workspace to left monitor" })
hl.bind(mod .. " + CTRL + F10", hl.dsp.workspace.move({ monitor = "right" }), { description = "workspace to right monitor" })
hl.bind(mod .. " + CTRL + F11", hl.dsp.workspace.move({ monitor = "up" }), { description = "workspace to upper monitor" })
hl.bind(mod .. " + CTRL + F12", hl.dsp.workspace.move({ monitor = "down" }), { description = "workspace to lower monitor" })

----------------------------------------------------------------------
-- SCREENSHOTS  (laptop.lua has the same on F6, since there's no Print key)
----------------------------------------------------------------------

hl.bind(mod .. " + Print", sh(s .. "/screenshot.sh now"), { description = "screenshot" })
hl.bind(mod .. " + SHIFT + Print", sh(s .. "/screenshot.sh area"), { description = "screenshot area" })
hl.bind("ALT + Print", sh(s .. "/screenshot.sh window"), { description = "screenshot window" })
hl.bind(mod .. " + SHIFT + S", sh(s .. "/screenshot.sh edit"), { description = "screenshot area + annotate" })
hl.bind(mod .. " + CTRL + Print", sh(s .. "/screenshot.sh in5"), { description = "screenshot in 5s" })
hl.bind(mod .. " + CTRL + SHIFT + Print", sh(s .. "/screenshot.sh in10"), { description = "screenshot in 10s" })

----------------------------------------------------------------------
-- WALLPAPER / DESKTOP
----------------------------------------------------------------------

hl.bind(mod .. " + W", glass("wallpaper"), { description = "pick wallpaper" })
hl.bind(mod .. " + SHIFT + W", glass("effects"), { description = "wallpaper effects" })
hl.bind("CTRL + ALT + W", sh(s .. "/wallpaper.sh random"), { description = "random wallpaper" })
hl.bind(mod .. " + CTRL + ALT + B", sh("pkill -SIGUSR1 waybar"), { description = "show/hide waybar" })
hl.bind(mod .. " + ALT + mouse_down", sh(s .. "/zoom.sh in"), { description = "zoom in" })
hl.bind(mod .. " + ALT + mouse_up", sh(s .. "/zoom.sh out"), { description = "zoom out" })

----------------------------------------------------------------------
-- HARDWARE KEYS  (work on the lock screen too)
----------------------------------------------------------------------

hl.bind("XF86AudioRaiseVolume", sh(s .. "/volume.sh up"), { description = "volume up", locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", sh(s .. "/volume.sh down"), { description = "volume down", locked = true, repeating = true })
hl.bind("XF86AudioMute", sh(s .. "/volume.sh mute"), { description = "mute", locked = true })
hl.bind("XF86AudioMicMute", sh(s .. "/volume.sh mic-mute"), { description = "mute mic", locked = true })
-- XF86AudioPlayPause doesn't exist in this xkb setup; Play and Pause cover that key.
hl.bind("XF86AudioPlay", sh(s .. "/media.sh play-pause"), { description = "play / pause", locked = true })
hl.bind("XF86AudioPause", sh(s .. "/media.sh play-pause"), { description = "play / pause", locked = true })
hl.bind("XF86AudioNext", sh(s .. "/media.sh next"), { description = "next track", locked = true })
hl.bind("XF86AudioPrev", sh(s .. "/media.sh prev"), { description = "previous track", locked = true })
hl.bind("XF86AudioStop", sh(s .. "/media.sh stop"), { description = "stop", locked = true })
hl.bind("XF86Sleep", sh("systemctl suspend"), { description = "sleep", locked = true })
hl.bind("XF86Rfkill", sh(s .. "/airplane.sh"), { description = "airplane mode", locked = true })

-- Keyboard layout (us/ara) switches with ALT+SHIFT via kb_options in settings.lua.
