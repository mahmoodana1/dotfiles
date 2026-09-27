-- Main Hyprland settings: layout, input, gestures, misc.
-- https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
    dwindle = {
        preserve_split       = true,
        -- smart_split       = true,
        special_scale_factor = 0.8,
    },

    master = {
        new_status = "master",
        new_on_top = true,
        mfact      = 0.5,
    },

    general = {
        resize_on_border = true,
        layout           = "dwindle",
    },

    input = {
        -- Caps-Lock acts as CTRL, Alt+Shift toggles layout.
        kb_layout  = "us,ara",
        kb_variant = "",
        kb_model   = "",
        kb_options = "ctrl:nocaps, grp:alt_shift_toggle",
        kb_rules   = "",

        repeat_rate  = 50,
        repeat_delay = 300,

        sensitivity = 0, -- mouse sensitivity, -1.0 to 1.0
        -- accel_profile = "",  -- flat | adaptive | empty for libinput's default
        numlock_by_default          = true,
        left_handed                 = false,
        follow_mouse                = 1,
        float_switch_override_focus = false,

        touchpad = {
            disable_while_typing   = true,
            natural_scroll         = true,
            clickfinger_behavior   = false,
            middle_button_emulation = false,
            tap_to_click           = true, -- was tap-to-click in .conf
            drag_lock              = false,
        },

        -- touchscreen devices
        touchdevice = {
            enabled = true,
        },

        tablet = {
            transform   = 0,
            left_handed = false,
        },
    },

    gestures = {
        workspace_swipe_distance           = 500,
        workspace_swipe_invert             = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio       = 0.5,
        workspace_swipe_create_new         = true,
        workspace_swipe_forever            = true,
    },

    misc = {
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        vrr                        = 2,
        mouse_move_enables_dpms    = true,
        enable_swallow             = false,
        swallow_regex              = "^(kitty)$",
        focus_on_activate          = false,
        initial_workspace_tracking = 0,
        middle_click_paste         = false,
        enable_anr_dialog          = true, -- Application Not Responding dialog
        anr_missed_pings           = 15,   -- default of 1 is too low
        allow_session_lock_restore = true, -- prevents lockscreen crash on resume
    },

    -- opengl = { nvidia_anti_flicker = true },

    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles   = true,
        pass_mouse_when_bound    = false,
    },

    -- Helps when scaling, avoids pixelation
    xwayland = {
        enabled            = true,
        force_zero_scaling = true,
    },

    render = {
        direct_scanout = 0,
    },

    cursor = {
        sync_gsettings_theme    = true,
        no_hardware_cursors     = 2,      -- auto: hardware cursor (screens are on Intel), so moving the mouse no longer recomposites
        enable_hyprcursor       = true,
        -- The pointer stays put when you switch workspaces, and follows the
        -- keyboard when focus moves inside a workspace (ALT+TAB, SUPER+arrows).
        warp_on_change_workspace = 0,
        no_warps                = false,
    },
})

-- Gestures. https://wiki.hypr.land/Configuring/Basics/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 3-finger up/down zooms the screen magnifier in/out.
local zoom = os.getenv("HOME") .. "/.config/hypr/scripts/zoom.sh"
hl.gesture({ fingers = 3, direction = "up",   action = function() hl.dispatch(hl.dsp.exec_cmd(zoom .. " in")) end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.dispatch(hl.dsp.exec_cmd(zoom .. " out")) end })
