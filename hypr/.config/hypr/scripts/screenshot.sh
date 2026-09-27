#!/usr/bin/env bash
# Screenshots. Every shot is saved to ~/Pictures/Screenshots and copied to the clipboard.
#   screenshot.sh now      whole screen
#   screenshot.sh area     drag to select
#   screenshot.sh window   active window
#   screenshot.sh edit     select an area, then annotate it in swappy
#   screenshot.sh in5 | in10   whole screen after a countdown

dir="$(xdg-user-dir PICTURES)/Screenshots"
file="$dir/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
mkdir -p "$dir"

countdown() {
    for s in $(seq "$1" -1 1); do
        notify-send -e -t 1000 -i timer -h string:x-canonical-private-synchronous:shot "Screenshot in $s…"
        sleep 1
    done
    sleep 0.5  # let the last countdown notification fade out of the shot
}

case "$1" in
    now)    grim "$file" ;;
    area)   geo=$(slurp) || exit 0; grim -g "$geo" "$file" ;;
    window) geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
            grim -g "$geo" "$file" ;;
    edit)   geo=$(slurp) || exit 0; grim -g "$geo" - | swappy -f - ; exit 0 ;;
    in5)    countdown 5;  grim "$file" ;;
    in10)   countdown 10; grim "$file" ;;
    *) echo "usage: $0 now|area|window|edit|in5|in10" >&2; exit 2 ;;
esac

[ -s "$file" ] || { notify-send -u normal -i dialog-error "Screenshot failed"; exit 1; }
wl-copy < "$file"

# Clicking "Open" views it, "Delete" throws it away.
action=$(notify-send -e -i "$file" -A open=Open -A delete=Delete \
         -h string:x-canonical-private-synchronous:shot "Screenshot saved" "$(basename "$file")")
case "$action" in
    open)   xdg-open "$file" ;;
    delete) rm -f "$file" ;;
esac
