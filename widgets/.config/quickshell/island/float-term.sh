#!/bin/sh
# Open a TUI in a floating terminal: Omarchy's styled one when present,
# otherwise alacritty with the class the Hyprland window rules float.
# usage: float-term.sh <command> [args...]
if command -v omarchy-launch-tui >/dev/null 2>&1; then
    exec omarchy-launch-tui "$@"
fi
exec setsid -f alacritty --class alacritty-float -e "$@"
