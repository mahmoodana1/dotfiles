#!/usr/bin/env bash
# Switch between the Peek glass bar (Quickshell, ~/.config/quickshell/peek)
# and the regular waybar. Waybar's own config/style links are never touched.
#
#   PeekBar.sh on       stop waybar, start Peek
#   PeekBar.sh off      stop Peek, start waybar
#   PeekBar.sh toggle   on <-> off
#   PeekBar.sh boot     start whichever is selected (called from startup.lua)
set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/peek-bar"
MODE="$STATE_DIR/on"

is_on() { [ -e "$MODE" ]; }

# Hard-kill every Peek instance: a graceful quit crashes in Quickshell 0.3.1
# screencopy teardown, and its crash handler then relaunches a second bar.
stop_peek() {
  qs list --all 2>/dev/null | awk '
    /^Instance/ { pid = "" }
    /Process ID:/ { pid = $3 }
    /Config path:.*\/quickshell\/peek\/shell.qml/ { print pid }' | xargs -r kill -9
  pkill -f 'quickshell/peek/[s]uperwatch.py'
}

start_peek() {
  stop_peek
  setsid -f qs -c peek >/dev/null 2>&1
}

start_waybar() {
  pgrep -x waybar >/dev/null || setsid -f waybar >/dev/null 2>&1
}

stop_waybar() {
  pkill -x waybar
  while pgrep -x waybar >/dev/null; do sleep 0.1; done
}

case "${1:-}" in
  on)
    mkdir -p "$STATE_DIR"; touch "$MODE"
    stop_waybar; start_peek
    notify-send -e -u low "Bar" "Peek on — hold SUPER (SUPER+SHIFT+B for waybar)" 2>/dev/null ;;
  off)
    rm -f "$MODE"
    stop_peek; start_waybar
    notify-send -e -u low "Bar" "Waybar restored" 2>/dev/null ;;
  toggle)
    if is_on; then "$0" off; else "$0" on; fi ;;
  boot)
    if is_on && command -v qs >/dev/null; then start_peek; else start_waybar; fi ;;
  *) echo "usage: $0 {on|off|toggle|boot}" >&2; exit 2 ;;
esac
