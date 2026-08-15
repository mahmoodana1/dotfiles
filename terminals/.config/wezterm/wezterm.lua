local wezterm = require("wezterm")
local config = {}

-- Force software renderer
config.front_end = "Software"

-- Font
config.font = wezterm.font("JetBrains Mono")
config.font_size = 12.0

-- Simple colors (you can re-add Catppuccin later)
config.color_scheme = "Builtin Solarized Dark"

return config
