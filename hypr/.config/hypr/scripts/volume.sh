#!/usr/bin/env bash
# Volume keys.   volume.sh up | down | mute | mic-mute
# The Dynamic Island shows its own OSD, so notifications are skipped in island mode.

STEP=5
MAX=150

osd() {
    grep -qx island "$HOME/.local/state/peek-bar/mode" 2>/dev/null && return
    notify-send -e -u low -h string:x-canonical-private-synchronous:volume "$@"
}

show() {
    if [ "$(pamixer --get-mute)" = true ]; then
        osd -i audio-volume-muted "Volume" "Muted"
    else
        local v; v=$(pamixer --get-volume)
        osd -i audio-volume-high -h int:value:"$v" "Volume" "$v%"
    fi
}

case "$1" in
    up)       pamixer -u; pamixer -i "$STEP" --allow-boost --set-limit "$MAX"; show ;;
    down)     pamixer -u; pamixer -d "$STEP"; show ;;
    mute)     pamixer -t; show ;;
    mic-mute)
        pamixer --default-source -t
        if [ "$(pamixer --default-source --get-mute)" = true ]; then
            osd -i microphone-sensitivity-muted "Microphone" "Off"
        else
            osd -i audio-input-microphone "Microphone" "On"
        fi ;;
    *) echo "usage: $0 up|down|mute|mic-mute" >&2; exit 2 ;;
esac
