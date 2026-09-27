-- Window and layer rules. https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- Most rules work through tags: tag an app once (TAGS), then style the tag
-- (FLOAT / SIZE / ...). To make a new app float at 70%: add its class to the
-- "settings" tag. Find a window's class with:  hyprctl clients

local function tag_class(name, pattern)
    hl.window_rule({ match = { class = pattern }, tag = "+" .. name })
end

local function tag_title(name, pattern)
    hl.window_rule({ match = { title = pattern }, tag = "+" .. name })
end

-- Several rules for one match:  rules({ class = "^(x)$" }, { float = true, center = true })
local function rules(match, props)
    for k, v in pairs(props) do
        hl.window_rule({ match = match, [k] = v })
    end
end

----------------------------------------------------------------------
-- TAGS
----------------------------------------------------------------------

tag_class("browser", "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|zen|zen-alpha)$")
tag_class("browser", "^([Gg]oogle-chrome(-beta|-dev|-unstable)?|[Cc]hromium|chrome-.+-Default|Brave-browser)$")
tag_class("terminal", "^(Alacritty|kitty)$")
tag_class("projects", "^(codium|VSCodium|VSCode|code-url-handler|jetbrains-.+)$")
tag_class("im", "^([Dd]iscord|[Vv]esktop|org.telegram.desktop|[Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap|[Ff]erdium|Element)$")
tag_class("games", "^(gamescope|steam_app_\\d+)$")
tag_class("video", "^([Mm]pv|com.github.rafostar.Clapper)$")

-- small utility windows: float, 70% of the screen, centered
tag_class("settings", "^(nm-applet|nm-connection-editor|blueman-manager|nwg-displays|nwg-look)$")
tag_class("settings", "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$")
tag_class("settings", "^(qt5ct|qt6ct|[Yy]ad|xdg-desktop-portal-gtk|file-roller|org.gnome.FileRoller)$")
tag_class("settings", "^(gnome-disks|[Bb]aobab|org.gnome.[Bb]aobab|wihotspot(-gui)?)$")
tag_title("settings", "^(ROG Control|Kvantum Manager)$")

-- viewers: float at their natural size
tag_class("viewer", "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$")
tag_class("viewer", "^(evince|eog|org.gnome.Loupe)$")

----------------------------------------------------------------------
-- TAG STYLES
----------------------------------------------------------------------

rules({ tag = "settings*" }, { float = true, center = true, size = "monitor_w*0.7 monitor_h*0.7" })
rules({ tag = "viewer*" }, { float = true })
rules({ tag = "video*" }, { float = true, no_blur = true, opacity = 1.0 })
rules({ tag = "terminal*" }, { opacity = "0.98 0.98" })

----------------------------------------------------------------------
-- APPS AND DIALOGS
----------------------------------------------------------------------

-- SUPER+SHIFT+Return
rules({ class = "^(alacritty-float)$" }, { float = true, center = true, size = "monitor_w*0.7 monitor_h*0.7" })

-- Dedicated-workspace TUIs, launched with a unique --class by their scripts
-- (SUPER+T taskvim.sh, SUPER+A openclaw-tui.sh; dojo is in dojo.lua).
rules({ class = "^(taskvim)$" }, { workspace = "8", fullscreen = true })
rules({ class = "^(openclaw-tui)$" }, { workspace = "5", fullscreen = true })
rules({ class = "^(floating-openclaw)$" }, { float = true, center = true, opacity = "0.95 0.95" })

-- File dialogs and prompts
rules({ title = "^(Save As|Open Files|Add Folder to Workspace)$" }, { float = true, center = true, size = "monitor_w*0.7 monitor_h*0.6" })
rules({ title = "^(Authentication Required)$" }, { float = true, center = true })
rules({ class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" }, { float = true, center = true }) -- thunar's dialogs, not its main window
rules({ class = "^([Ss]team)$", title = "negative:^([Ss]team)$" }, { float = true })            -- steam's popups
rules({ class = "(org.gnome.Calculator|[Qq]alculate-gtk)" }, { float = true })
rules({ class = "^([Zz]oom|onedriver|onedriver-launcher)$" }, { float = true })
rules({ class = "^([Ff]erdium|[Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, { float = true, center = true, size = "monitor_w*0.6 monitor_h*0.7" })

-- Picture-in-picture: pinned in the top-right corner
rules({ title = "^(Picture-in-Picture)$" }, { float = true, pin = true, keep_aspect_ratio = true, move = "monitor_w*0.72 monitor_h*0.07" })

-- Don't let IDE hover popups steal focus
hl.window_rule({ match = { class = "^(jetbrains-.*)" }, no_initial_focus = true })
hl.window_rule({ match = { title = "^(wind.*)$" }, no_initial_focus = true })

-- Never go idle/lock while something is fullscreen
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })

----------------------------------------------------------------------
-- LAYERS (bars, launchers, notifications)
----------------------------------------------------------------------

hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0 })

-- Glass panels (qs -c glass): Hyprland frosts only what's behind the card body
-- (ignore_alpha skips the transparent rest of the full-screen layer); the
-- shader adds the water edge and tint. The pour animation is drawn by Quickshell.
hl.layer_rule({ match = { namespace = "glass" }, blur = true })
hl.layer_rule({ match = { namespace = "glass" }, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "glass" }, no_anim = true })
