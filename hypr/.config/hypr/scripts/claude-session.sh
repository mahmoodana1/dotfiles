#!/bin/sh
# SUPER+A target: focus the Claude Code session if it is already running,
# otherwise launch it on workspace 5. The window rules in lua/windowrules.lua pin the
# `claude-session` class to workspace 5 and force fullscreen, so placement
# happens before the window maps — no sleep, no flicker.
#
# Note: this Hyprland build (Lua config) evaluates `hyprctl dispatch`
# arguments as Lua, so dispatches must use hl.dsp.* call syntax.

CLASS=claude-session

hyprctl dispatch 'hl.dsp.focus({ workspace = 5 })'

if ! hyprctl clients -j | grep -q "\"class\": \"$CLASS\""; then
    # Login zsh so PATH/env match an interactive terminal session.
    setsid -f alacritty --class "$CLASS" -T "Claude" \
        -e zsh -lc 'cd ~/claude && exec claude --model claude-sonnet-5-5' \
        >/dev/null 2>&1
fi
