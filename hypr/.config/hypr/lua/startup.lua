-- Autostart. https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- These run inside hl.on("hyprland.start", ...) so they fire once per session,
-- matching the old exec-once behaviour rather than re-running on every reload.

local d = require("defaults")

local scripts = d.scriptsDir
local user    = d.userScripts
local term    = d.terminal

hl.on("hyprland.start", function()
    -- Initial boot script: applies initial wallpapers, theming and new settings.
    -- It self-disables once ~/.config/hypr/.initial_startup_done exists, so
    -- leave both this line and that reference file alone.
    hl.exec_cmd(d.home .. "/.config/hypr/initial-boot.sh")

    -- Wallpaper daemon
    hl.exec_cmd("awww-daemon --format xrgb")
    -- hl.exec_cmd("mpvpaper '*' -o \"load-scripts=no no-audio --loop\" <file>")
    -- hl.exec_cmd(user .. "/WallpaperAutoChange.sh " .. d.wallDir) -- random wallpaper every 30 min

    -- Session environment
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd(scripts .. "/KeybindsLayoutInit.sh")

    -- Dropdown terminal. See JaKooLit/Hyprland-Dots#810
    hl.exec_cmd(scripts .. "/Dropterminal.sh " .. term .. " &")

    -- Polkit agent (GNOME / KDE)
    hl.exec_cmd(scripts .. "/Polkit.sh")

    -- Tray and shell
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("nm-tray")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waybar")
    hl.exec_cmd("qs") -- quickshell, the AGS desktop-overview alternative
    hl.exec_cmd("ags")
    hl.exec_cmd("blueman-applet")
    -- hl.exec_cmd("rog-control-center")

    -- Hold-to-show HUD panel daemon (SUPER+SHIFT+P)
    hl.exec_cmd(d.home .. "/.config/hypr/panel/panel.py")

    -- Auto-hide driver for the Peek waybar (inert unless that layout is active)
    hl.exec_cmd(scripts .. "/WaybarPeek.py")

    -- Clipboard manager
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Rainbow borders (drives general:col.active_border at runtime)
    hl.exec_cmd(user .. "/RainbowBorders.sh")

    -- Idle daemon, which in turn starts hyprlock
    hl.exec_cmd("hypridle")

    -- Restore hyprsunset state from the previous session
    hl.exec_cmd(scripts .. "/Hyprsunset.sh init")

    -- xdg-desktop-portal-hyprland (usually autostarts; forced here)
    hl.exec_cmd(scripts .. "/PortalHyprland.sh")

    -- Open firefox on workspace 9
    hl.exec_cmd("hyprctl dispatch workspace 9 | firefox --class floating-zenbrowser -o initial_window_width=90c -o initial_window_height=24c")
end)
