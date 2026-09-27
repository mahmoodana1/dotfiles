#!/usr/bin/env bash
# Media keys.   media.sh play-pause | next | prev | stop

case "$1" in
    play-pause) playerctl play-pause ;;
    next)       playerctl next ;;
    prev)       playerctl previous ;;
    stop)       playerctl stop ;;
    *) echo "usage: $0 play-pause|next|prev|stop" >&2; exit 2 ;;
esac

sleep 0.2
case "$(playerctl status 2>/dev/null)" in
    Playing) msg="$(playerctl metadata --format '{{title}} — {{artist}}')" ;;
    Paused)  msg="Paused" ;;
    *)       msg="Stopped" ;;
esac
notify-send -e -u low -i audio-x-generic -h string:x-canonical-private-synchronous:media "Media" "$msg"
