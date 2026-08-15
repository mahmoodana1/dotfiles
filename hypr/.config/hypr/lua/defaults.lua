-- User defaults and paths.
--
-- NOTE: ~/.config/hypr/UserConfigs/01-UserDefaults.conf is intentionally kept on
-- disk. Hyprland no longer sources it, but several JaKooLit shell scripts still
-- grep it for $term / $files / $edit / $Search_Engine. Keep the two in sync.

local home = os.getenv("HOME")

return {
    home        = home,
    scriptsDir  = home .. "/.config/hypr/scripts",
    userScripts = home .. "/.config/hypr/UserScripts",
    userConfigs = home .. "/.config/hypr/UserConfigs",
    wallDir     = home .. "/Pictures/wallpapers",

    -- $term / $files from 01-UserDefaults.conf
    terminal    = "alacritty",
    fileManager = "thunar",

    mainMod     = "SUPER",
}
