-- Autostart: runs once per login (not on every `hyprctl reload`).
-- To add an app: add a line to the list below.
-- To pin it to a workspace: { "cmd", workspace = "9 silent" }

local d = require("defaults")
local s = d.scripts

local autostart = {
    -- Session plumbing
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "/usr/lib/hyprpolkitagent/hyprpolkitagent",   -- password prompts for GUI apps

    -- Desktop
    "awww-daemon --format xrgb",                  -- wallpaper (remembers the last image)
    s .. "/wallpaper.sh restore",                 -- ...or restarts a video wallpaper
    s .. "/bar.sh boot",                          -- island / peek / waybar (SUPER+SHIFT+B)
    -- glass panels, on Intel (they capture the screen); restarted if they ever exit
    "sh -c 'while :; do env __NV_PRIME_RENDER_OFFLOAD=0 qs -c glass; sleep 1; done'",
    "swaync",                                     -- notifications
    d.home .. "/.config/hypr/panel/panel.py",     -- prayer times: alerts + the HUD's data
    "hypridle",                                   -- idle -> lock
    "wl-paste --type text --watch cliphist store",  -- clipboard history
    "wl-paste --type image --watch cliphist store", -- (browse: cliphist list | fzf ...)
    "nm-applet --indicator",
    "blueman-applet",

    -- Apps
    { d.browser, workspace = "9 silent" },
}

hl.on("hyprland.start", function()
    for _, app in ipairs(autostart) do
        if type(app) == "string" then
            hl.exec_cmd(app)
        else
            hl.exec_cmd(app[1], { workspace = app.workspace })
        end
    end
end)
