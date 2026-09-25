#!/usr/bin/env bash
# Control for the auto-hiding "Peek" waybar (see WaybarPeek.py).
#
#   WaybarPeek.sh on       switch to Peek layout+style (remembers the current ones)
#   WaybarPeek.sh off      restore the layout+style that were active before `on`
#   WaybarPeek.sh toggle   on <-> off
#   WaybarPeek.sh press    SUPER pressed  (from the Hyprland bind)
#   WaybarPeek.sh release  SUPER released (from the Hyprland bind)
set -u

WB="$HOME/.config/waybar"
PEEK_CONFIG="$WB/configs/[TOP] Peek"
PEEK_STYLE="$WB/style/[Peek] Minimal.css"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-peek"
RESTORE="$STATE_DIR/restore"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-peek.pid"
DAEMON="$HOME/.config/hypr/scripts/WaybarPeek.py"

is_on() { [ "$(readlink "$WB/config")" = "$PEEK_CONFIG" ]; }

restart_waybar() {
  pkill -x waybar
  while pgrep -x waybar >/dev/null; do sleep 0.1; done
  setsid -f waybar >/dev/null 2>&1
}

ensure_daemon() {
  if ! { [ -r "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }; then
    setsid -f "$DAEMON" >/dev/null 2>&1
  fi
}

signal_daemon() {
  [ -r "$PID_FILE" ] || exit 0
  kill -"$1" "$(cat "$PID_FILE")" 2>/dev/null || true
}

turn_on() {
  is_on && { ensure_daemon; return; }
  mkdir -p "$STATE_DIR"
  printf '%s\n%s\n' "$(readlink "$WB/config")" "$(readlink "$WB/style.css")" > "$RESTORE"
  ln -sfn "$PEEK_CONFIG" "$WB/config"
  ln -sfn "$PEEK_STYLE" "$WB/style.css"
  ensure_daemon
  restart_waybar
  notify-send -e -u low "Waybar" "Peek mode on (SUPER+SHIFT+B to restore)" 2>/dev/null
}

turn_off() {
  is_on || return
  if [ -r "$RESTORE" ]; then
    { read -r cfg; read -r css; } < "$RESTORE"
  else
    cfg="$WB/configs/[TOP] Everforest"; css="$WB/style/[Extra] ML4W starter.css"
  fi
  ln -sfn "$cfg" "$WB/config"
  ln -sfn "$css" "$WB/style.css"
  restart_waybar
  notify-send -e -u low "Waybar" "Restored: $(basename "$cfg")" 2>/dev/null
}

case "${1:-}" in
  on)      turn_on ;;
  off)     turn_off ;;
  toggle)  if is_on; then turn_off; else turn_on; fi ;;
  press)   signal_daemon USR1 ;;
  release) signal_daemon USR2 ;;
  *) echo "usage: $0 {on|off|toggle|press|release}" >&2; exit 2 ;;
esac
