#!/usr/bin/env bash
# Wrapper around nwg-displays for the Lua config format.
#
# nwg-displays can only write the legacy .conf format, which Hyprland 0.57+
# no longer reads. This launches it, then converts its output into
# lua/monitors.lua and lua/workspaces.lua and reloads Hyprland.
#
# Use this instead of calling nwg-displays directly.

set -euo pipefail

SCRIPTSDIR="$HOME/.config/hypr/scripts"

nwg-displays "$@"

python3 "$SCRIPTSDIR/nwg-displays-to-lua.py"

hyprctl reload >/dev/null 2>&1 || true

if command -v notify-send >/dev/null 2>&1; then
    notify-send -u low -i video-display "Displays" "Monitor layout converted to Lua and reloaded"
fi
