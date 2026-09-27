#!/usr/bin/env bash
# Screen magnifier.   zoom.sh in | out | reset
# (SUPER+ALT+scroll, and 3-finger swipe up/down)

cur=$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {print $2}')

case "$1" in
    in)    new=$(awk -v f="$cur" 'BEGIN { print f * 1.5 }') ;;
    out)   new=$(awk -v f="$cur" 'BEGIN { f /= 1.5; print (f < 1 ? 1 : f) }') ;;
    reset) new=1 ;;
    *) echo "usage: $0 in|out|reset" >&2; exit 2 ;;
esac

hyprctl eval "hl.config({ cursor = { zoom_factor = $new } })" >/dev/null
