#!/usr/bin/env bash
# Toggle airplane mode (all radios) — XF86Rfkill and the swaync button.

if rfkill list wifi | grep -q "Soft blocked: yes"; then
    rfkill unblock all; msg="Off"
else
    rfkill block all;   msg="On"
fi
notify-send -e -u low -i airplane-mode -h string:x-canonical-private-synchronous:airplane "Airplane mode" "$msg"
