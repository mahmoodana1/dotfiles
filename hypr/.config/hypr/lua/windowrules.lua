-- Window and layer rules.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
--
-- Order matters: vendor defaults first (was configs/WindowRules.conf), then the
-- user additions (was UserConfigs/WindowRules.conf).

local function tag_class(name, pattern)
    hl.window_rule({ match = { class = pattern }, tag = "+" .. name })
end

local function tag_title(name, pattern)
    hl.window_rule({ match = { title = pattern }, tag = "+" .. name })
end

----------------------------------------------------------------------
-- TAGS -- group apps so they share settings
----------------------------------------------------------------------

-- browsers
tag_class("browser", "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$")
tag_class("browser", "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$")
tag_class("browser", "^(chrome-.+-Default)$") -- Chrome PWAs
tag_class("browser", "^([Cc]hromium)$")
tag_class("browser", "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$")
tag_class("browser", "^(Brave-browser(-beta|-dev|-unstable)?)$")
tag_class("browser", "^([Tt]horium-browser|[Cc]achy-browser)$")
tag_class("browser", "^(zen-alpha|zen)$")

-- notifications
tag_class("notif", "^(swaync-control-center|swaync-notification-window|swaync-client|class)$")

-- KooL settings
tag_title("KooL_Cheat", "^(KooL Quick Cheat Sheet)$")
tag_title("KooL_Settings", "^(KooL Hyprland Settings)$")
tag_class("KooL-Settings", "^(nwg-displays|nwg-look)$")

-- terminals
tag_class("terminal", "^(Alacritty|kitty|kitty-dropterm)$")

-- email
tag_class("email", "^([Tt]hunderbird|org.gnome.Evolution)$")
tag_class("email", "^(eu.betterbird.Betterbird)$")

-- projects
tag_class("projects", "^(codium|codium-url-handler|VSCodium)$")
tag_class("projects", "^(VSCode|code-url-handler)$")
tag_class("projects", "^(jetbrains-.+)$") -- JetBrains IDEs

-- screenshare
tag_class("screenshare", "^(com.obsproject.Studio)$")

-- instant messaging
tag_class("im", "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$")
tag_class("im", "^([Ff]erdium)$")
tag_class("im", "^([Ww]hatsapp-for-linux)$")
tag_class("im", "^(ZapZap|com.rtosta.zapzap)$")
tag_class("im", "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$")
tag_class("im", "^(teams-for-linux)$")
tag_class("im", "^(im.riot.Riot|Element)$") -- Element Matrix client

-- games
tag_class("games", "^(gamescope)$")
tag_class("games", "^(steam_app_\\d+)$")

-- game stores
tag_class("gamestore", "^([Ss]team)$")
tag_title("gamestore", "^([Ll]utris)$")
tag_class("gamestore", "^(com.heroicgameslauncher.hgl)$")

-- file managers
tag_class("file-manager", "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$")
tag_class("file-manager", "^(app.drey.Warp)$")

-- wallpaper
tag_class("wallpaper", "^([Ww]aytrogen)$")

-- multimedia
tag_class("multimedia", "^([Aa]udacious)$")
tag_class("multimedia_video", "^([Mm]pv|vlc)$")

-- settings
tag_title("settings", "^(ROG Control)$")
tag_class("settings", "^(wihotspot(-gui)?)$")                    -- wifi hotspot
tag_class("settings", "^([Bb]aobab|org.gnome.[Bb]aobab)$")       -- disk usage analyzer
tag_class("settings", "^(gnome-disks|wihotspot(-gui)?)$")
tag_title("settings", "(Kvantum Manager)")
tag_class("settings", "^(file-roller|org.gnome.FileRoller)$")    -- archive manager
tag_class("settings", "^(nm-applet|nm-connection-editor|blueman-manager)$")
tag_class("settings", "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$")
tag_class("settings", "^(qt5ct|qt6ct|[Yy]ad)$")
tag_class("settings", "(xdg-desktop-portal-gtk)")
tag_class("settings", "^(org.kde.polkit-kde-authentication-agent-1)$")
tag_class("settings", "^([Rr]ofi)$")

-- viewers
tag_class("viewer", "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$")
tag_class("viewer", "^(evince)$")            -- document viewer
tag_class("viewer", "^(eog|org.gnome.Loupe)$") -- image viewer

----------------------------------------------------------------------
-- OVERRIDES
----------------------------------------------------------------------

hl.window_rule({ match = { tag = "multimedia_video*" }, no_blur = true })
hl.window_rule({ match = { tag = "multimedia_video*" }, opacity = 1.0 })

----------------------------------------------------------------------
-- POSITION
----------------------------------------------------------------------

-- hl.window_rule({ match = { float = true }, center = true }) -- warning: also centers menus
hl.window_rule({ match = { tag = "KooL_Cheat*" }, center = true })
hl.window_rule({ match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" }, center = true })
hl.window_rule({ match = { title = "^(ROG Control)$" }, center = true })
hl.window_rule({ match = { tag = "KooL-Settings*" }, center = true })
hl.window_rule({ match = { title = "^(Keybindings)$" }, center = true })
hl.window_rule({ match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" }, center = true })
hl.window_rule({ match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, center = true })
hl.window_rule({ match = { class = "^([Ff]erdium)$" }, center = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, move = "monitor_w*0.72 monitor_h*0.07" })

-- avoid idle for fullscreen apps
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })

-- Move to workspace (disabled by default, kept for reference)
-- hl.window_rule({ match = { tag = "email*" },   workspace = "1" })
-- hl.window_rule({ match = { tag = "browser*" }, workspace = "2" })
-- hl.window_rule({ match = { tag = "projects*" }, workspace = "3" })
-- hl.window_rule({ match = { tag = "screenshare*" }, workspace = "4 silent" })
-- hl.window_rule({ match = { class = "^(virt-manager)$" }, workspace = "6 silent" })

----------------------------------------------------------------------
-- FLOAT
----------------------------------------------------------------------

hl.window_rule({ match = { tag = "KooL_Cheat*" },    float = true })
hl.window_rule({ match = { tag = "wallpaper*" },     float = true })
hl.window_rule({ match = { tag = "settings*" },      float = true })
hl.window_rule({ match = { tag = "viewer*" },        float = true })
hl.window_rule({ match = { tag = "KooL-Settings*" }, float = true })
hl.window_rule({ match = { class = "([Zz]oom|onedriver|onedriver-launcher)$" }, float = true })
hl.window_rule({ match = { class = "(org.gnome.Calculator)", title = "(Calculator)" }, float = true })
hl.window_rule({ match = { class = "^(mpv|com.github.rafostar.Clapper)$" }, float = true })
hl.window_rule({ match = { class = "^([Qq]alculate-gtk)$" }, float = true })
hl.window_rule({ match = { class = "^([Ff]erdium)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true })
hl.window_rule({ match = { class = "^(alacritty-float)$" }, float = true })
hl.window_rule({ match = { class = "^(alacritty-float)$" }, size = "monitor_w*0.7 monitor_h*0.7" }) -- 1344x756 on 1080p
hl.window_rule({ match = { class = "^(alacritty-float)$" }, center = true })

-- float popups and dialogues
hl.window_rule({ match = { title = "^(Authentication Required)$" }, float = true })
hl.window_rule({ match = { title = "^(Authentication Required)$" }, center = true })
hl.window_rule({ match = { class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" }, float = true })
hl.window_rule({ match = { class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" }, float = true })
hl.window_rule({ match = { class = "^([Ss]team)$", title = "negative:^([Ss]team)$" }, float = true })
hl.window_rule({ match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" }, float = true })

hl.window_rule({ match = { title = "^(Add Folder to Workspace)$" }, float = true })
hl.window_rule({ match = { title = "^(Add Folder to Workspace)$" }, size = "monitor_w*0.7 monitor_h*0.6" })
hl.window_rule({ match = { title = "^(Add Folder to Workspace)$" }, center = true })

hl.window_rule({ match = { title = "^(Save As)$" }, float = true })
hl.window_rule({ match = { title = "^(Save As)$" }, size = "monitor_w*0.7 monitor_h*0.6" })
hl.window_rule({ match = { title = "^(Save As)$" }, center = true })

-- KooL's dots YAD for setting the SDDM background
hl.window_rule({ match = { title = "^(SDDM Background)$" }, float = true })
hl.window_rule({ match = { title = "^(SDDM Background)$" }, center = true })
hl.window_rule({ match = { title = "^(SDDM Background)$" }, size = "monitor_w*0.16 monitor_h*0.12" })

----------------------------------------------------------------------
-- SIZE
----------------------------------------------------------------------

hl.window_rule({ match = { tag = "KooL_Cheat*" }, size = "monitor_w*0.65 monitor_h*0.9" })
hl.window_rule({ match = { tag = "wallpaper*" },  size = "monitor_w*0.7 monitor_h*0.7" })
hl.window_rule({ match = { tag = "settings*" },   size = "monitor_w*0.7 monitor_h*0.7" })
hl.window_rule({ match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" }, size = "monitor_w*0.6 monitor_h*0.7" })
hl.window_rule({ match = { class = "^([Ff]erdium)$" }, size = "monitor_w*0.6 monitor_h*0.7" })

----------------------------------------------------------------------
-- PINNING AND EXTRAS
----------------------------------------------------------------------

hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, pin = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, keep_aspect_ratio = true })

-- Stops IntelliJ hover popups from stealing focus
hl.window_rule({ match = { class = "^(jetbrains-*)" }, no_initial_focus = true })
hl.window_rule({ match = { title = "^(wind.*)$" },     no_initial_focus = true })

hl.window_rule({ match = { fullscreen = false }, border_color = "rgb(FFFFFF) rgb(cacaca)" })

----------------------------------------------------------------------
-- USER ADDITIONS (was UserConfigs/WindowRules.conf)
----------------------------------------------------------------------

hl.window_rule({ match = { title = "^(Authentication Required|Add Folder to Workspace|Save As|SDDM Background)$" }, center = true })
hl.window_rule({ match = { title = "^(ROG Control|Keybindings)$" }, center = true })
hl.window_rule({ match = { class = "^(org.gnome.Calculator)$", title = "(Calculator)" }, float = true })
hl.window_rule({ match = { class = "^(Zoom|onedriver|onedriver-launcher)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture|Authentication Required|Save As|Add Folder to Workspace|Open Files|SDDM Background)$" }, float = true })
hl.window_rule({ match = { tag = "terminal*" }, opacity = "0.98 0.98" })
hl.window_rule({ match = { title = "^(SDDM Background)$" }, size = "monitor_w*0.16 monitor_h*0.12" })
hl.window_rule({ match = { title = "^(Add Folder to Workspace|Save As|Open Files)$" }, size = "monitor_w*0.7 monitor_h*0.6" })

-- TUIs with a dedicated home workspace. Both are launched from a script with a
-- unique --class, so these rules place and fullscreen them before they map.
-- SUPER+T → UserScripts/taskvim-launch.sh, SUPER+A → scripts/OpenTui.sh
hl.window_rule({ match = { class = "^(taskvim)$" }, workspace = "8" })
hl.window_rule({ match = { class = "^(taskvim)$" }, fullscreen = true })
hl.window_rule({ match = { class = "^(openclaw-tui)$" }, workspace = "5" })
hl.window_rule({ match = { class = "^(openclaw-tui)$" }, fullscreen = true })

tag_class("browser", "^(chrome-.+-Default)$")
tag_class("projects", "^(jetbrains-.+)$")
tag_class("settings", "^(wihotspot(-gui)?|gnome-disks|file-roller|org.gnome.FileRoller|nm-applet|nm-connection-editor|blueman-manager|pavucontrol|org.pulseaudio.pavucontrol|qt5ct|qt6ct|[Yy]ad|xdg-desktop-portal-gtk|org.kde.polkit-kde-authentication-agent-1)$")
tag_title("settings", "^(ROG Control|Kvantum Manager)$")
tag_class("viewer", "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter|evince|eog|org.gnome.Loupe)$")

-- OpenClaw chat popup
hl.window_rule({ match = { class = "^(floating-openclaw)$" }, float = true })
hl.window_rule({ match = { class = "^(floating-openclaw)$" }, center = true })
hl.window_rule({ match = { class = "^(floating-openclaw)$" }, opacity = "0.95 0.95" })

----------------------------------------------------------------------
-- LAYER RULES
----------------------------------------------------------------------

hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, ignore_alpha = 0 })

hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, ignore_alpha = 0 })

hl.layer_rule({ match = { namespace = "quickshell:overview" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, ignore_alpha = 0.5 })
