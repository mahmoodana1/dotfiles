-- Shared names used across the other lua/ files. Change an app here and every
-- bind/rule that uses it follows.

local home = os.getenv("HOME")

return {
    home        = home,
    scripts     = home .. "/.config/hypr/scripts",

    terminal    = "alacritty",
    fileManager = "thunar",
    browser     = "firefox",

    mainMod     = "SUPER",
}
