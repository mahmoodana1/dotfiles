#!/usr/bin/env bash
# Show or hide the HUD panel. Exits 0 even when the daemon is absent, so a
# missing daemon never turns a keypress into an error.
set -u

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"

case "${1:-}" in
  show) SIG=USR1 ;;
  hide) SIG=USR2 ;;
  *) echo "usage: $0 {show|hide}" >&2; exit 2 ;;
esac

[ -r "$PID_FILE" ] || exit 0

PID=$(cat "$PID_FILE" 2>/dev/null) || exit 0
case "$PID" in
  ''|*[!0-9]*) exit 0 ;;
esac

if ! kill -0 "$PID" 2>/dev/null; then
  rm -f "$PID_FILE"      # stale
  exit 0
fi

kill -"$SIG" "$PID" 2>/dev/null || true
exit 0
