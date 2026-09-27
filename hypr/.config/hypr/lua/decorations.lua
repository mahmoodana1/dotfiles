-- Borders, gaps, rounding, opacity, shadow, blur.
-- Colors come from ~/.config/palette/palette.conf (run palette-apply after editing it).
-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration

local c = require("colors")

hl.config({
    general = {
        border_size = 1,
        gaps_in = 5,
        gaps_out = 9,

        col = {
            active_border = c.border_active,
            inactive_border = c.border_inactive,
        },
    },

    decoration = {
        rounding = 4,

        active_opacity = 1,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,

        dim_inactive = true,
        dim_strength = 0.1,
        dim_special = 0.9,

        shadow = {
            enabled = true,
            range = 0,
            render_power = 1,
            color = c.color12,
            color_inactive = c.color10,
        },

        blur = {
            enabled = true,
            size = 10,
            passes = 2,
            new_optimizations = true,
            special = true,
        },
    },

    group = {
        col = {
            border_active = c.color15,
        },

        groupbar = {
            col = {
                active = c.color0,
            },
        },
    },
})
