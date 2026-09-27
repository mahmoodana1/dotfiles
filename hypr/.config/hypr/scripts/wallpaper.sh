#!/usr/bin/env bash
# Wallpapers from ~/Pictures/wallpapers (images, gifs, and videos via mpvpaper).
#   wallpaper.sh set <file>      apply an image, gif or video
#   wallpaper.sh effect <name>   apply an effect to the current image ("None" restores it)
#   wallpaper.sh random          random image                      (CTRL+ALT+W)
#   wallpaper.sh auto [min]      new random image every N minutes (default 30)
#   wallpaper.sh restore         at login: restart a video wallpaper if one was set
#   wallpaper.sh list            "<file>\t<thumbnail>" per wallpaper (for the glass picker)
#   wallpaper.sh effects         effect names, one per line
#
# The picker itself is the glass panel (SUPER+W, SUPER+SHIFT+W for effects).
# The current image is copied to ~/.cache/wallpaper/current (hyprlock uses it).

WALLS="$HOME/Pictures/wallpapers"
CACHE="$HOME/.cache/wallpaper"
TRANSITION=(--transition-type any --transition-fps 60 --transition-duration 2 --transition-bezier .43,1.19,1,.4)
mkdir -p "$CACHE"

monitor() { hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'; }
is_video() { [[ "${1,,}" =~ \.(mp4|mkv|mov|webm)$ ]]; }
list() {
    find -L "$WALLS" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
        -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \) | sort
}

set_image() {
    pkill -x mpvpaper; rm -f "$CACHE/video"
    pgrep -x awww-daemon >/dev/null || { awww-daemon --format xrgb & sleep 0.5; }
    awww img -o "$(monitor)" "$1" "${TRANSITION[@]}"
    [ "$2" = keep-original ] || cp -f "$1" "$CACHE/current"
}

set_video() {
    pkill -x mpvpaper
    mpvpaper '*' -o "load-scripts=no no-audio --loop" "$1" >/dev/null 2>&1 &
    echo "$1" > "$CACHE/video"
}

apply() { if is_video "$1"; then set_video "$1"; else set_image "$1"; fi; }

# A thumbnail for rofi: images are their own; gifs and videos get a cached still frame.
thumb() {
    local f="$1" t="$CACHE/thumbs/$(basename "$1").png"
    if [[ "${f,,}" =~ \.gif$ ]] || is_video "$f"; then
        mkdir -p "$CACHE/thumbs"
        if [ ! -f "$t" ]; then
            if is_video "$f"; then ffmpeg -v error -y -ss 1 -i "$f" -vframes 1 "$t"
            else magick "$f[0]" -resize 640x "$t"; fi
        fi
        echo "$t"
    else
        echo "$f"
    fi
}

# ImageMagick flags per effect. Add one here and it shows up in the picker.
declare -A FX=(
    ["None"]=""
    ["Black & White"]="-colorspace gray -sigmoidal-contrast 10,40%"
    ["Blurred"]="-blur 0x10"
    ["Charcoal"]="-charcoal 0x5"
    ["Oil Paint"]="-paint 4"
    ["Posterize"]="-posterize 4"
    ["Sepia"]="-sepia-tone 65%"
    ["Vignette"]="-background black -vignette 0x3"
    ["Negate"]="-negate"
)

effect() {
    local in="$CACHE/current" out="$CACHE/modified"
    [ -n "${FX[$1]+x}" ] || { echo "unknown effect: $1" >&2; exit 1; }
    if [ -z "${FX[$1]}" ]; then
        set_image "$in" keep-original
    else
        # shellcheck disable=SC2086  # the effect string is a list of magick flags
        magick "$in" ${FX[$1]} "$out" && set_image "$out" keep-original
    fi
}

case "$1" in
    set)     [ -f "$2" ] || { echo "no such file: $2" >&2; exit 1; }; apply "$2" ;;
    effect)  effect "$2" ;;
    random)  set_image "$(list | grep -viE '\.(mp4|mkv|mov|webm)$' | shuf -n1)" ;;
    auto)    while :; do "$0" random; sleep $(( ${2:-30} * 60 )); done ;;
    restore) [ -f "$CACHE/video" ] && set_video "$(cat "$CACHE/video")" ;;
    list)    list | while read -r f; do printf '%s	%s
' "$f" "$(thumb "$f")"; done ;;
    effects) printf '%s
' "${!FX[@]}" | sort ;;
    *) echo "usage: $0 set <file>|effect <name>|random|auto [minutes]|restore|list|effects" >&2; exit 2 ;;
esac
