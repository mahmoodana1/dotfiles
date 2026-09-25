-- Keybinds (merged from configs/Keybinds.conf and UserConfigs/UserKeybinds.conf).
-- https://wiki.hypr.land/Configuring/Basics/Binds/

local d = require("defaults")

local mod = d.mainMod
local scripts = d.scriptsDir
local user = d.userScripts
local term = d.terminal
local files = d.fileManager

local function sh(cmd)
    return hl.dsp.exec_cmd(cmd)
end

----------------------------------------------------------------------
-- SESSION
----------------------------------------------------------------------

hl.bind("CTRL + ALT + Delete", hl.dsp.exit(), { description = "exit Hyprland" })
hl.bind(mod .. " + Q", hl.dsp.window.close(), { description = "close active window" })
hl.bind(mod .. " + SHIFT + Q", sh(scripts .. "/KillActiveProcess.sh"), { description = "terminate active process" })
hl.bind("CTRL + ALT + L", sh(scripts .. "/LockScreen.sh"), { description = "lock screen" })
hl.bind("CTRL + ALT + P", sh(scripts .. "/Wlogout.sh"), { description = "powermenu" })
hl.bind(mod .. " + SHIFT + N", sh("swaync-client -t -sw"), { description = "notification panel" })
hl.bind(mod .. " + SHIFT + E", sh(scripts .. "/Kool_Quick_Settings.sh"), { description = "quick settings menu" })

----------------------------------------------------------------------
-- LAYOUTS
----------------------------------------------------------------------

-- Master layout
hl.bind(mod .. " + CTRL + D", hl.dsp.layout("removemaster"), { description = "remove master" })
hl.bind(mod .. " + I", hl.dsp.layout("addmaster"), { description = "add master" })
-- NOTE: J/K are bound dynamically by scripts/KeybindsLayoutInit.sh and
-- scripts/ChangeLayout.sh, so they are deliberately not bound statically here.
hl.bind(mod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"), { description = "swap with master" })

-- Dwindle layout
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("togglesplit"), { description = "toggle split (dwindle)" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(), { description = "toggle pseudo (dwindle)" })

-- Either layout
hl.bind(mod .. " + M", sh("hyprctl dispatch splitratio 0.3"), { description = "set split ratio 0.3" })

-- Groups
hl.bind(mod .. " + G", hl.dsp.group.toggle(), { description = "toggle group" })
-- legacy `changegroupactive` with no argument cycled forward
hl.bind(mod .. " + CTRL + tab", hl.dsp.group.next(), { description = "change active in group" })

-- Cycle windows; if floating, bring to top
hl.bind("ALT + tab", hl.dsp.window.cycle_next(), { description = "cycle next window" })
hl.bind("ALT + tab", hl.dsp.window.bring_to_top(), { description = "bring active to top" })

----------------------------------------------------------------------
-- HARDWARE KEYS
----------------------------------------------------------------------

hl.bind(
    "XF86AudioRaiseVolume",
    sh(scripts .. "/Volume.sh --inc"),
    { description = "volume up", locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    sh(scripts .. "/Volume.sh --dec"),
    { description = "volume down", locked = true, repeating = true }
)
hl.bind(
    "XF86AudioMicMute",
    sh(scripts .. "/Volume.sh --toggle-mic"),
    { description = "toggle mic mute", locked = true }
)
hl.bind("XF86AudioMute", sh(scripts .. "/Volume.sh --toggle"), { description = "toggle mute", locked = true })
hl.bind("XF86Sleep", sh("systemctl suspend"), { description = "sleep", locked = true })
hl.bind("XF86Rfkill", sh(scripts .. "/AirplaneMode.sh"), { description = "airplane mode", locked = true })

-- Media controls
-- NOTE: the old config also bound XF86AudioPlayPause, but that keysym does not
-- exist in this xkb setup and Hyprland rejects it. XF86AudioPlay and
-- XF86AudioPause below cover the same hardware key.
hl.bind("XF86AudioPause", sh(scripts .. "/MediaCtrl.sh --pause"), { description = "pause", locked = true })
hl.bind("XF86AudioPlay", sh(scripts .. "/MediaCtrl.sh --pause"), { description = "play", locked = true })
hl.bind("XF86AudioNext", sh(scripts .. "/MediaCtrl.sh --nxt"), { description = "next track", locked = true })
hl.bind("XF86AudioPrev", sh(scripts .. "/MediaCtrl.sh --prv"), { description = "previous track", locked = true })
hl.bind("XF86AudioStop", sh(scripts .. "/MediaCtrl.sh --stop"), { description = "stop", locked = true })

----------------------------------------------------------------------
-- SCREENSHOTS
----------------------------------------------------------------------

hl.bind(mod .. " + Print", sh(scripts .. "/ScreenShot.sh --now"), { description = "screenshot now" })
hl.bind(mod .. " + SHIFT + Print", sh(scripts .. "/ScreenShot.sh --area"), { description = "screenshot (area)" })
hl.bind(mod .. " + CTRL + Print", sh(scripts .. "/ScreenShot.sh --in5"), { description = "screenshot in 5s" })
hl.bind(mod .. " + CTRL + SHIFT + Print", sh(scripts .. "/ScreenShot.sh --in10"), { description = "screenshot in 10s" })
hl.bind("ALT + Print", sh(scripts .. "/ScreenShot.sh --active"), { description = "screenshot active window" })
hl.bind(mod .. " + SHIFT + S", sh(scripts .. "/ScreenShot.sh --swappy"), { description = "screenshot (swappy)" })

----------------------------------------------------------------------
-- WINDOW MANAGEMENT
----------------------------------------------------------------------

-- Resize
hl.bind(
    mod .. " + SHIFT + left",
    hl.dsp.window.resize({ x = -50, y = 0, relative = true }),
    { description = "resize left (-50)", repeating = true }
)
hl.bind(
    mod .. " + SHIFT + right",
    hl.dsp.window.resize({ x = 50, y = 0, relative = true }),
    { description = "resize right (+50)", repeating = true }
)
hl.bind(
    mod .. " + SHIFT + up",
    hl.dsp.window.resize({ x = 0, y = -50, relative = true }),
    { description = "resize up (-50)", repeating = true }
)
hl.bind(
    mod .. " + SHIFT + down",
    hl.dsp.window.resize({ x = 0, y = 50, relative = true }),
    { description = "resize down (+50)", repeating = true }
)

-- Move
hl.bind(mod .. " + CTRL + left", hl.dsp.window.move({ direction = "left" }), { description = "move window left" })
hl.bind(mod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }), { description = "move window right" })
hl.bind(mod .. " + CTRL + up", hl.dsp.window.move({ direction = "up" }), { description = "move window up" })
hl.bind(mod .. " + CTRL + down", hl.dsp.window.move({ direction = "down" }), { description = "move window down" })

-- Swap
hl.bind(mod .. " + ALT + left", hl.dsp.window.swap({ direction = "left" }), { description = "swap window left" })
hl.bind(mod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }), { description = "swap window right" })
hl.bind(mod .. " + ALT + up", hl.dsp.window.swap({ direction = "up" }), { description = "swap window up" })
hl.bind(mod .. " + ALT + down", hl.dsp.window.swap({ direction = "down" }), { description = "swap window down" })

-- Focus
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "focus left" })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "focus right" })
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "focus up" })
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "focus down" })

----------------------------------------------------------------------
-- WORKSPACES
----------------------------------------------------------------------

hl.bind(mod .. " + tab", hl.dsp.focus({ workspace = "m+1" }), { description = "next workspace" })
hl.bind(mod .. " + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }), { description = "previous workspace" })

-- Special workspace
hl.bind(
    mod .. " + SHIFT + U",
    hl.dsp.window.move({ workspace = "special" }),
    { description = "move to special workspace" }
)
hl.bind(mod .. " + U", hl.dsp.workspace.toggle_special(), { description = "toggle special workspace" })

-- Key codes are used so the binds survive keyboard layout changes.
-- code:10 is key 1, code:11 is key 2, ... code:19 is key 0.
for i = 1, 10 do
    local code = "code:" .. (9 + i)
    local ws = i

    hl.bind(mod .. " + " .. code, hl.dsp.focus({ workspace = ws }), { description = "workspace " .. ws })

    hl.bind(
        mod .. " + SHIFT + " .. code,
        hl.dsp.window.move({ workspace = ws }),
        { description = "move to workspace " .. ws }
    )

    hl.bind(
        mod .. " + CTRL + " .. code,
        hl.dsp.window.move({ workspace = ws, silent = true }),
        { description = "move silently to workspace " .. ws }
    )
end

hl.bind(
    mod .. " + SHIFT + bracketleft",
    hl.dsp.window.move({ workspace = "-1" }),
    { description = "move to previous workspace" }
)
hl.bind(
    mod .. " + SHIFT + bracketright",
    hl.dsp.window.move({ workspace = "+1" }),
    { description = "move to next workspace" }
)
hl.bind(
    mod .. " + CTRL + bracketleft",
    hl.dsp.window.move({ workspace = "-1", silent = true }),
    { description = "move silently to previous workspace" }
)
hl.bind(
    mod .. " + CTRL + bracketright",
    hl.dsp.window.move({ workspace = "+1", silent = true }),
    { description = "move silently to next workspace" }
)

-- Scroll / step through workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }), { description = "next workspace" })
hl.bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }), { description = "previous workspace" })

-- Move current workspace between monitors
hl.bind(
    mod .. " + CTRL + F9",
    hl.dsp.workspace.move({ monitor = "left" }),
    { description = "move workspace to left monitor" }
)
hl.bind(
    mod .. " + CTRL + F10",
    hl.dsp.workspace.move({ monitor = "right" }),
    { description = "move workspace to right monitor" }
)
hl.bind(
    mod .. " + CTRL + F11",
    hl.dsp.workspace.move({ monitor = "up" }),
    { description = "move workspace to up monitor" }
)
hl.bind(
    mod .. " + CTRL + F12",
    hl.dsp.workspace.move({ monitor = "down" }),
    { description = "move workspace to down monitor" }
)

-- Move/resize with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { description = "move window", mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { description = "resize window", mouse = true })

----------------------------------------------------------------------
-- LAUNCHERS
----------------------------------------------------------------------

hl.bind(
    mod .. " + D",
    sh("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"),
    { description = "app launcher" }
)
hl.bind(mod .. " + B", sh('xdg-open "https://"'), { description = "open default browser" })
hl.bind(mod .. " + A", sh(scripts .. "/OpenTui.sh"), { description = "open OpenClaw TUI" })
hl.bind(mod .. " + ALT + A", sh(scripts .. "/OverviewToggle.sh"), { description = "desktop overview" })
hl.bind(mod .. " + Return", sh(term), { description = "open terminal" })
hl.bind(mod .. " + E", sh(files), { description = "file manager" })
hl.bind(mod .. " + F", sh(term .. " -e bash -lc " .. os.getenv("HOME") .. "/.local/bin/tmux-sessionizer"), { description = "tmux sessionizer (pick project)" })
-- Size/float/center come from the alacritty-float window rules (windowrules.lua),
-- applied as the window maps. A post-launch resize raced the window opening.
hl.bind(
    mod .. " + SHIFT + Return",
    sh(term .. " --class alacritty-float"),
    { description = "floating terminal (focused)" }
)

----------------------------------------------------------------------
-- FEATURES / EXTRAS
----------------------------------------------------------------------

hl.bind(mod .. " + H", sh(os.getenv("HOME") .. "/.local/bin/shortcut-viewer"), { description = "shortcut viewer (rofi, from shortcuts.md)" })
hl.bind(mod .. " + ALT + R", sh(scripts .. "/Refresh.sh"), { description = "refresh bar and menus" })
hl.bind(mod .. " + ALT + E", sh(scripts .. "/RofiEmoji.sh"), { description = "emoji menu" })
hl.bind(mod .. " + S", sh(scripts .. "/RofiSearch.sh"), { description = "web search" })
hl.bind(mod .. " + CTRL + S", sh("rofi -show window"), { description = "window switcher" })
hl.bind(mod .. " + ALT + O", sh(scripts .. "/ChangeBlur.sh"), { description = "toggle blur" })
hl.bind(mod .. " + SHIFT + G", sh(scripts .. "/GameMode.sh"), { description = "toggle game mode" })
hl.bind(mod .. " + ALT + L", sh(scripts .. "/ChangeLayout.sh"), { description = "toggle master/dwindle layout" })
hl.bind(mod .. " + ALT + V", sh(scripts .. "/ClipManager.sh"), { description = "clipboard manager" })
hl.bind(mod .. " + CTRL + R", sh(scripts .. "/RofiThemeSelector.sh"), { description = "rofi theme selector" })
hl.bind(
    mod .. " + CTRL + SHIFT + R",
    sh("pkill rofi || true && " .. scripts .. "/RofiThemeSelector-modified.sh"),
    { description = "rofi theme selector (modified)" }
)

hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen(), { description = "fullscreen" })
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen(1), { description = "maximize window" })
hl.bind(mod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }), { description = "float current window" })
hl.bind(mod .. " + ALT + SPACE", sh("hyprctl dispatch workspaceopt allfloat"), { description = "float all windows" })

-- Desktop zoom / magnifier
hl.bind(
    mod .. " + ALT + mouse_down",
    sh(
        [[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')"]]
    ),
    { description = "zoom in" }
)
hl.bind(
    mod .. " + ALT + mouse_up",
    sh(
        [[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')"]]
    ),
    { description = "zoom out" }
)

-- Waybar
hl.bind(mod .. " + CTRL + ALT + B", sh("pkill -SIGUSR1 waybar"), { description = "toggle waybar on/off" })
hl.bind(mod .. " + CTRL + B", sh(scripts .. "/WaybarStyles.sh"), { description = "waybar styles menu" })
hl.bind(mod .. " + ALT + B", sh(scripts .. "/WaybarLayout.sh"), { description = "waybar layout menu" })

-- Night light
hl.bind(mod .. " + N", sh(scripts .. "/Hyprsunset.sh toggle"), { description = "toggle night light" })

-- UserScripts
hl.bind(mod .. " + SHIFT + M", sh(user .. "/RofiBeats.sh"), { description = "online music" })
hl.bind(mod .. " + W", sh(user .. "/WallpaperSelect.sh"), { description = "select wallpaper" })
hl.bind(mod .. " + SHIFT + W", sh(user .. "/WallpaperEffects.sh"), { description = "wallpaper effects" })
hl.bind("CTRL + ALT + W", sh(user .. "/WallpaperRandom.sh"), { description = "random wallpaper" })
hl.bind(
    mod .. " + CTRL + O",
    sh("hyprctl setprop active opaque toggle"),
    { description = "toggle active window opacity" }
)
hl.bind(mod .. " + SHIFT + K", sh(scripts .. "/KeyBinds.sh"), { description = "search keybinds" })
hl.bind(mod .. " + SHIFT + A", sh(scripts .. "/Animations.sh"), { description = "animations menu" })
hl.bind(mod .. " + SHIFT + O", sh(user .. "/ZshChangeTheme.sh"), { description = "change oh-my-zsh theme" })
hl.bind(mod .. " + ALT + C", sh(user .. "/RofiCalc.sh"), { description = "calculator" })
hl.bind(mod .. " + T", sh(user .. "/taskvim-launch.sh"), { description = "open taskvim (ws8 fullscreen)" })

-- Keyboard layout switching. Non-consuming so the modifiers still reach apps.
hl.bind(
    "ALT_L + SHIFT_L",
    sh(scripts .. "/SwitchKeyboardLayout.sh"),
    { description = "switch keyboard layout globally", locked = true, non_consuming = true }
)
hl.bind(
    "SHIFT_L + ALT_L",
    sh(scripts .. "/Tak0-Per-Window-Switch.sh"),
    { description = "switch keyboard layout per-window", locked = true, non_consuming = true }
)

-- Keyboard passthrough into a VM
-- hl.define_submap("passthru", "reset", function()
--     hl.bind(mod .. " + ALT + P", hl.dsp.submap("reset"))
-- end)
-- hl.bind(mod .. " + ALT + P", hl.dsp.submap("passthru"))
