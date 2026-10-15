#!/bin/sh
# SUPER+A target: focus the OpenClaw TUI if it is already running, otherwise
# launch it on workspace 5. The window rules in lua/windowrules.lua pin the
# `openclaw-tui` class to workspace 5 and force fullscreen, so placement
# happens before the window maps — no sleep, no flicker.
#
# Note: this Hyprland build (0.56, Lua config) evaluates `hyprctl dispatch`
# arguments as Lua, so dispatches must use hl.dsp.* call syntax — the legacy
# `dispatch workspace 5` form is a Lua syntax error here.

CLASS=openclaw-tui

hyprctl dispatch 'hl.dsp.focus({ workspace = 5 })'

if ! hyprctl clients -j | grep -q "\"class\": \"$CLASS\""; then
    # The token lives in ~/.config/secrets.env, which is machine-local and
    # deliberately absent from the dotfiles repo.
    [ -f "$HOME/.config/secrets.env" ] && . "$HOME/.config/secrets.env"

    # ~/.local/bin/openclaw-tui puts the nvm node bin dir on PATH and execs
    # `openclaw tui "$@"`, so the token flag passes straight through.
    setsid -f alacritty --class "$CLASS" -T "OpenClaw TUI" \
        -e "$HOME/.local/bin/openclaw-tui" \
        --token "$OPENCLAW_TOKEN" \
        >/dev/null 2>&1
fi
