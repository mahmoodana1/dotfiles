#!/usr/bin/env bash
# Top-bar switcher. Three modes; the choice persists across logins.
#   waybar  the regular waybar (config/style links are never touched)
#   peek    liquid-glass bar, shown while SUPER is held   (~/.config/quickshell/peek)
#   island  liquid-glass Dynamic Island that pops on events (~/.config/quickshell/island)
#
#   bar.sh cycle          waybar -> peek -> island -> waybar   (SUPER+SHIFT+B)
#   bar.sh set <mode>     switch to a mode
#   bar.sh boot           start the selected mode (startup.lua)
#   bar.sh on|off|toggle  old names: peek / waybar / cycle
set -u
# The bars capture the screen, which lives on the Intel GPU; keep them there
# even though apps default to the NVIDIA card (see hypr/lua/env.lua).
export __NV_PRIME_RENDER_OFFLOAD=0

# Qt steps animations by the PRIMARY screen's refresh (eDP, 60 Hz) even on the
# 100 Hz monitor, so springs judder there. The simple driver advances them by
# real elapsed time instead: smooth on every monitor.
export QSG_USE_SIMPLE_ANIMATION_DRIVER=1

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/peek-bar"
MODE_FILE="$STATE_DIR/mode"          # volume.sh/brightness.sh read this too
DND_FILE="$STATE_DIR/dnd-before-island"
mkdir -p "$STATE_DIR"
[ -e "$STATE_DIR/on" ] && { echo peek > "$MODE_FILE"; rm -f "$STATE_DIR/on"; }  # migrate

current() { cat "$MODE_FILE" 2>/dev/null || echo waybar; }

# Hard-kill a Quickshell config's instances: a graceful quit crashes in
# Quickshell 0.3.1 screencopy teardown, and its crash handler then relaunches
# a second copy.
stop_qs() {
  qs list --all 2>/dev/null | awk -v cfg="/quickshell/$1/shell.qml" '
    /^Instance/ { pid = "" }
    /Process ID:/ { pid = $3 }
    /Config path:/ && index($0, cfg) { print pid }' | xargs -r kill -9
  pkill -f "quickshell/(peek|island)/(shared/)?[s]uperwatch.py"
  pkill -f "quickshell/island/[n]otifwatch.py"
}

start_waybar() { pgrep -x waybar >/dev/null || setsid -f waybar >/dev/null 2>&1; }
stop_waybar() {
  pkill -x waybar
  while pgrep -x waybar >/dev/null; do sleep 0.1; done
}

# swaync keeps collecting notifications; only its popups step aside
island_dnd_on() {
  [ -e "$DND_FILE" ] || swaync-client -D > "$DND_FILE" 2>/dev/null
  swaync-client -dn >/dev/null 2>&1
}
island_dnd_off() {
  [ -e "$DND_FILE" ] || return 0
  [ "$(cat "$DND_FILE")" = true ] || swaync-client -df >/dev/null 2>&1
  rm -f "$DND_FILE"
}

stop_all() {
  stop_qs peek; stop_qs island; island_dnd_off; stop_waybar
}

start_mode() {
  case "$1" in
    peek)   setsid -f qs -c peek >/dev/null 2>&1 ;;
    island) island_dnd_on; setsid -f qs -c island >/dev/null 2>&1 ;;
    *)      start_waybar ;;
  esac
}

set_mode() {
  local m="$1"
  case "$m" in waybar|peek|island) ;; *) echo "unknown mode: $m" >&2; exit 2 ;; esac
  command -v qs >/dev/null || m=waybar
  echo "$m" > "$MODE_FILE"
  stop_all
  start_mode "$m"
  case "$m" in
    peek)   msg="Peek — hold SUPER" ;;
    island) msg="Dynamic Island — pops on events, hold SUPER for all" ;;
    *)      msg="Waybar" ;;
  esac
  notify-send -e -u low "Bar" "$msg  (SUPER+SHIFT+B to cycle)" 2>/dev/null
}

case "${1:-}" in
  set)    set_mode "${2:-}" ;;
  cycle|toggle)
    case "$(current)" in
      waybar) set_mode peek ;;
      peek)   set_mode island ;;
      *)      set_mode waybar ;;
    esac ;;
  on)     set_mode peek ;;
  off)    set_mode waybar ;;
  boot)
    m="$(current)"
    command -v qs >/dev/null || m=waybar
    stop_all
    start_mode "$m" ;;
  *) echo "usage: $0 {cycle|set <waybar|peek|island>|boot}" >&2; exit 2 ;;
esac
