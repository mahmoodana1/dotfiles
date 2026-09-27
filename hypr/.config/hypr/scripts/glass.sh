#!/usr/bin/env bash
# Open/close the glass panels (qs -c glass, see ~/.config/quickshell/glass).
#   glass.sh toggle|open|dismiss <panel>[:arg]
#   panels: launcher shortcuts wallpaper wallpaper:effects windows power hud
# If the glass shell isn't running, the launcher and window switcher fall back
# to rofi so you're never left without them.

action="${1:?usage: glass.sh toggle|open|dismiss <panel>}"
panel="${2:?usage: glass.sh toggle|open|dismiss <panel>}"

qs ipc -c glass call glass "$action" "$panel" 2>/dev/null && exit 0

[ "$action" = dismiss ] && exit 0
case "${panel%%:*}" in
    launcher) pkill -x rofi; exec rofi -show drun ;;
    windows)  pkill -x rofi; exec rofi -show window ;;
    hud)      exit 0 ;;   # hold-to-show fires many times a second; stay quiet
    *)        notify-send -u low -i dialog-warning "Glass panels" "The glass shell isn't running. Start it with: qs -c glass" ;;
esac
