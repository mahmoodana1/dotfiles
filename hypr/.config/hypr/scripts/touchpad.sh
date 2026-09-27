#!/usr/bin/env bash
# Toggle the touchpad (XF86TouchpadToggle). Resets to "on" on config reload.
# Find your device name with:  hyprctl devices

DEVICE="etps/2-elantech-touchpad"
STATE="$XDG_RUNTIME_DIR/touchpad-off"

if [ -e "$STATE" ]; then
    rm "$STATE"; on=true;  msg="On"
else
    touch "$STATE"; on=false; msg="Off"
fi

# This Hyprland build runs Lua configs, so runtime changes go through `hyprctl eval`.
hyprctl eval "hl.device({ name = \"$DEVICE\", enabled = $on })" >/dev/null
notify-send -e -u low -i input-touchpad -h string:x-canonical-private-synchronous:touchpad "Touchpad" "$msg"
