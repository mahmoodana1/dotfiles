#!/usr/bin/env bash
# Brightness keys.   brightness.sh up | down          (screen)
#                    brightness.sh kbd-up | kbd-down  (keyboard backlight)

STEP=10

osd() {
    grep -qx island "$HOME/.local/state/peek-bar/mode" 2>/dev/null && return
    notify-send -e -u low -h string:x-canonical-private-synchronous:brightness "$@"
}

percent() { brightnessctl "$@" -m | cut -d, -f4 | tr -d %; }

case "$1" in
    up)       brightnessctl -q set "$STEP%+" ;;
    down)     [ "$(percent)" -gt "$STEP" ] && brightnessctl -q set "$STEP%-" ;;  # never fully black
    kbd-up)   brightnessctl -q -d '*::kbd_backlight' set 30%+ ;;
    kbd-down) brightnessctl -q -d '*::kbd_backlight' set 30%- ;;
    *) echo "usage: $0 up|down|kbd-up|kbd-down" >&2; exit 2 ;;
esac

case "$1" in
    kbd-*) v=$(percent -d '*::kbd_backlight'); osd -i keyboard-brightness -h int:value:"$v" "Keyboard" "$v%" ;;
    *)     v=$(percent);                        osd -i display-brightness  -h int:value:"$v" "Screen"   "$v%" ;;
esac
