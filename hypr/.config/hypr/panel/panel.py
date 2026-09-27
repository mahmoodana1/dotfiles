#!/usr/bin/env python3
"""Prayer-times daemon behind the HUD (hold SUPER+SHIFT+P).

Headless. It
  * writes the HUD's content to $XDG_RUNTIME_DIR/hud.json every few seconds,
    which the glass HUD (~/.config/quickshell/glass/Hud.qml) draws;
  * announces each adhan and iqama (alerts.py);
  * refreshes the published timetable every 6 hours (offline calculation
    covers any failure).

Debug: HUDPANEL_FAKE_NOW=2026-08-29T12:47 previews an arbitrary moment.
       --once writes hud.json once and exits.
"""
import os
import sys
import threading
import time

import alerts
import hudjson
import timetable

HUD_JSON = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hud.json")
TICK_S = 10                    # worst-case lateness of an alert / staleness of hud.json
REFRESH_INTERVAL_S = 6 * 60 * 60


def log(message: str) -> None:
    print(f"[hudpanel] {message}", file=sys.stderr, flush=True)


def refresh_timetable_async() -> None:
    """Refresh the timetable on a worker thread (network I/O never blocks ticks)."""
    def worker():
        try:
            if timetable.refresh():
                log("timetable refreshed from the published source")
        except Exception as exc:  # noqa: BLE001
            # The offline calculation covers us; a failed refresh is not fatal.
            log(f"timetable refresh failed, using computed times: {exc!r}")
    threading.Thread(target=worker, daemon=True, name="timetable").start()


class Daemon:
    def __init__(self):
        self.alert_events = []
        self.alert_day = None
        self.alert_last = None

    def tick(self) -> None:
        """Write hud.json and announce anything that came due since the last tick.

        Re-derives the day's events from wall-clock time on every tick, so a
        suspend/resume, a DST change, the day rolling over, or a timetable
        refresh all resolve themselves without special handling.
        """
        try:
            schedule = timetable.schedule()
        except Exception as exc:  # noqa: BLE001
            log(f"schedule failed: {exc!r}")
            return
        try:
            hudjson.write_atomic(HUD_JSON, hudjson.payload(schedule))
        except Exception as exc:  # noqa: BLE001
            log(f"writing {HUD_JSON} failed: {exc!r}")
        try:
            now = schedule["now"]
            if self.alert_day != schedule["date"]:
                self.alert_events = alerts.events_for(schedule)
                self.alert_day = schedule["date"]
                # Do not treat everything earlier today as newly due.
                if self.alert_last is None:
                    self.alert_last = now
            for when, kind, name in alerts.due_events(self.alert_events, self.alert_last, now):
                log(f"alert: {kind} {name} at {when:%H:%M}")
                alerts.announce(kind, name, schedule)
            self.alert_last = now
        except Exception as exc:  # noqa: BLE001
            # A broken tick must never take the daemon down with it.
            log(f"alert tick failed: {exc!r}")


def main() -> int:
    daemon = Daemon()
    if "--once" in sys.argv[1:]:
        daemon.tick()
        return 0

    refresh_timetable_async()
    next_refresh = time.monotonic() + REFRESH_INTERVAL_S
    log(f"ready, pid {os.getpid()}, writing {HUD_JSON}")
    while True:
        daemon.tick()
        if time.monotonic() >= next_refresh:
            refresh_timetable_async()
            next_refresh = time.monotonic() + REFRESH_INTERVAL_S
        time.sleep(TICK_S)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
