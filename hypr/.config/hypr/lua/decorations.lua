-- Decoration settings (from UserDecorations.conf).
-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration

local c = require("colors")

hl.config({
    general = {
        border_size = 1,
        gaps_in     = 2,
        gaps_out    = 2,

        col = {
            -- active_border is left unset on purpose: RainbowBorders.sh drives it
            -- at runtime via hyprctl.
            inactive_border = c.color10,
        },
    },

    decoration = {
        rounding = 10,

        active_opacity     = 1.0,
        inactive_opacity   = 0.9,
        fullscreen_opacity = 1.0,

        dim_inactive = true,
        dim_strength = 0.1,
        dim_special  = 0.8,

        shadow = {
            enabled        = true,
            range          = 2,
            render_power   = 1,
            color          = c.color12,
            color_inactive = c.color10,
        },

        blur = {
            enabled           = true,
            size              = 10,
            passes            = 2,
            new_optimizations = true,
            special           = true,
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
