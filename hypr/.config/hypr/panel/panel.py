#!/usr/bin/env python3
"""Hold-to-show HUD panel daemon.

Owns a layer-shell overlay surface, kept hidden until signalled:
  SIGUSR1 -> show on the focused monitor
  SIGUSR2 -> hide
"""

import os
import sys

# gtk4-layer-shell MUST be loaded before GTK4 initialises. Without this the
# window silently becomes an ordinary focusable toplevel. Re-exec ourselves so
# the daemon is correct however it was launched.
PRELOAD = "/usr/lib/libgtk4-layer-shell.so"


def _ensure_preload() -> None:
    current = os.environ.get("LD_PRELOAD", "")
    if PRELOAD in current.split(":"):
        return
    os.environ["LD_PRELOAD"] = f"{PRELOAD}:{current}" if current else PRELOAD
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__), *sys.argv[1:]])


_ensure_preload()

import signal  # noqa: E402
import threading  # noqa: E402

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LS  # noqa: E402

import alerts  # noqa: E402
import content  # noqa: E402
import monitor  # noqa: E402
import theme  # noqa: E402
import timetable  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
NAMESPACE = "hudpanel"
APP_ID = "dev.mahmood.hudpanel"
COLORS_LUA = os.path.join(HERE, "..", "lua", "colors.lua")
CSS_FILE = os.path.join(HERE, "panel.css")
PID_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr-panel.pid")
CARD_FRACTION = 0.6  # card is 60% of the monitor in both axes


REFRESH_INTERVAL_S = 6 * 60 * 60
ALERT_TICK_S = 10          # worst-case lateness of a prayer notification


def log(message: str) -> None:
    print(f"[hudpanel] {message}", file=sys.stderr, flush=True)


def refresh_timetable_async() -> bool:
    """Kick a timetable refresh on a worker thread.

    Never runs on the main loop: it does network I/O, and blocking here would
    freeze the panel. Returns True so it can be used as a GLib timeout source.
    """
    def worker():
        try:
            if timetable.refresh():
                log("timetable refreshed from the published source")
        except Exception as exc:  # noqa: BLE001
            # The offline calculation covers us; a failed refresh is not fatal.
            log(f"timetable refresh failed, using computed times: {exc!r}")

    threading.Thread(target=worker, daemon=True, name="timetable").start()
    return True


class Panel:
    # Must exceed input:repeat_delay (300ms) so a held key's first repeat
    # arrives before the watchdog fires, otherwise long holds flicker.
    WATCHDOG_MS = 450

    def __init__(self, app: Gtk.Application, oneshot: bool = False):
        self.app = app
        self.oneshot = oneshot
        self.window = None
        self.card = None
        self.last_monitor = None
        self.watchdog_id = 0
        self.alert_events = []
        self.alert_day = None
        self.alert_last = None

    def build(self) -> None:
        self.window = Gtk.Window()
        self.window.add_css_class("hudpanel")

        LS.init_for_window(self.window)
        LS.set_layer(self.window, LS.Layer.OVERLAY)
        LS.set_namespace(self.window, NAMESPACE)
        LS.set_keyboard_mode(self.window, LS.KeyboardMode.NONE)
        for edge in (LS.Edge.TOP, LS.Edge.BOTTOM, LS.Edge.LEFT, LS.Edge.RIGHT):
            LS.set_anchor(self.window, edge, True)
        LS.set_exclusive_zone(self.window, -1)

        if not LS.is_layer_window(self.window):
            log("FATAL: not a layer surface. Is LD_PRELOAD set correctly?")
            sys.exit(1)

        dim = Gtk.Box()
        dim.add_css_class("panel-dim")
        dim.set_hexpand(True)
        dim.set_vexpand(True)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        card.add_css_class("panel-card")
        # hexpand/vexpand make the box hand the card the FULL surface as its
        # allocation; halign/valign CENTER then centre the (60%-sized) card
        # inside that allocation. Without the expands the box gives the card
        # only its natural width and packs it hard against the left edge.
        card.set_hexpand(True)
        card.set_vexpand(True)
        card.set_halign(Gtk.Align.CENTER)
        card.set_valign(Gtk.Align.CENTER)

        dim.append(card)
        self.card = card
        self.window.set_child(dim)
        self.app.add_window(self.window)

    def alert_tick(self) -> bool:
        """Announce any prayer or iqama that has come due since the last tick.

        Re-derives the day's events from wall-clock time on every tick, so a
        suspend/resume, a DST change, the day rolling over, or a timetable
        refresh all resolve themselves without special handling.
        """
        try:
            schedule = timetable.schedule()
            now = schedule["now"]

            # Rebuild the event list when the day changes (or on first run).
            if self.alert_day != schedule["date"]:
                self.alert_events = alerts.events_for(schedule)
                self.alert_day = schedule["date"]
                # Do not treat everything earlier today as newly due.
                if self.alert_last is None:
                    self.alert_last = now

            for when, kind, name in alerts.due_events(
                    self.alert_events, self.alert_last, now):
                log(f"alert: {kind} {name} at {when:%H:%M}")
                alerts.announce(kind, name, schedule)

            self.alert_last = now
        except Exception as exc:  # noqa: BLE001
            # A broken tick must never take the daemon down with it.
            log(f"alert tick failed: {exc!r}")
        return True

    def _rebuild_content(self) -> None:
        """Rebuild the card's contents from scratch.

        Called on every show, not once at startup: the panel displays a clock
        and countdowns, so a tree built at login would be stale by the time it
        is first looked at.
        """
        child = self.card.get_first_child()
        while child is not None:
            following = child.get_next_sibling()
            self.card.remove(child)
            child = following

        # A broken content.py must not kill the daemon or leave a blank card.
        try:
            self.card.append(content.build())
        except Exception as exc:  # noqa: BLE001 - deliberate catch-all
            log(f"content.build() failed: {exc!r}")
            self.card.append(Gtk.Label(label=f"content error:\n{exc}"))

    def _size_card(self, mon) -> None:
        """Constrain the card's width; let its height follow the content.

        A fixed 60% height left a large dead void under the table. Width is
        still pinned so the card keeps a consistent shape across monitors and
        the text does not reflow as the day's content changes length.
        """
        if mon is None or self.card is None:
            return
        geo = mon.get_geometry()
        self.card.set_size_request(int(geo.width * CARD_FRACTION), -1)

    def load_css(self) -> None:
        try:
            body = open(CSS_FILE, encoding="utf-8").read()
        except OSError as exc:
            log(f"cannot read panel.css: {exc}")
            return
        css = theme.build_css(theme.load_palette_text(COLORS_LUA), body)
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def _target_monitor(self):
        name = monitor.query_focused_connector()
        display = Gdk.Display.get_default()
        if name:
            for mon in display.get_monitors():
                if mon.get_connector() == name:
                    self.last_monitor = mon
                    return mon
            log(f"focused connector {name!r} not found in GDK monitors")
        return self.last_monitor

    def report_geometry(self) -> bool:
        """Print where the card actually landed. Used by --oneshot to verify
        centring numerically rather than by eye."""
        if self.card is None or self.window is None:
            return False
        ok, bounds = self.card.compute_bounds(self.window)
        if not ok:
            log("could not compute card bounds")
            return False
        x, y = int(bounds.origin.x), int(bounds.origin.y)
        width, height = int(bounds.size.width), int(bounds.size.height)
        # A layer surface reports 0x0 from get_width()/get_height(); take the
        # dimensions from the monitor it is anchored to instead.
        if self.last_monitor is not None:
            geo = self.last_monitor.get_geometry()
            win_w, win_h = geo.width, geo.height
        else:
            win_w, win_h = self.window.get_width(), self.window.get_height()
        left = x
        right = win_w - (x + width)
        top = y
        bottom = win_h - (y + height)
        log(f"surface {win_w}x{win_h}  card {width}x{height} at ({x},{y})")
        log(f"margins  left={left} right={right} top={top} bottom={bottom}  "
            f"centred={'YES' if abs(left - right) <= 1 and abs(top - bottom) <= 1 else 'NO'}")
        return False

    def _cancel_watchdog(self) -> None:
        if self.watchdog_id:
            GLib.source_remove(self.watchdog_id)
            self.watchdog_id = 0

    def _on_watchdog(self) -> bool:
        self.watchdog_id = 0
        log("watchdog fired — no heartbeat, hiding")
        self.hide()
        return False

    def kick_watchdog(self) -> None:
        """Restart the dead-man timer. Called on every show heartbeat."""
        self._cancel_watchdog()
        self.watchdog_id = GLib.timeout_add(self.WATCHDOG_MS, self._on_watchdog)

    def show(self) -> None:
        # Kick first: a repeat heartbeat arriving while already visible must
        # still keep the panel alive. Skipped in oneshot mode, which has no
        # keybind feeding it heartbeats and is supposed to stay up on its own.
        if not self.oneshot:
            self.kick_watchdog()
        if self.window.get_visible():
            return
        self._rebuild_content()
        target = self._target_monitor()
        if target is not None:
            LS.set_monitor(self.window, target)
        self._size_card(target)
        self.window.set_visible(True)

    def hide(self) -> None:
        self._cancel_watchdog()
        if self.window.get_visible():
            self.window.set_visible(False)


def main() -> int:
    oneshot = "--oneshot" in sys.argv[1:]
    # Gtk.Application is single-instance per application_id over D-Bus. Without
    # NON_UNIQUE, running --oneshot while the daemon is up just forwards an
    # activate to the daemon and exits silently, so the render you asked for
    # never happens. --oneshot must always be its own process.
    flags = Gio.ApplicationFlags.NON_UNIQUE if oneshot else Gio.ApplicationFlags.DEFAULT_FLAGS
    app = Gtk.Application(application_id=APP_ID, flags=flags)
    panel = Panel(app, oneshot=oneshot)

    def on_activate(_app):
        panel.build()
        panel.load_css()

        if oneshot:
            panel.show()
            GLib.timeout_add(600, panel.report_geometry)
            GLib.timeout_add(3000, lambda: (app.quit(), False)[1])
            return

        app.hold()  # stay alive with no visible window

        # Handlers BEFORE the PID file. panelctl only signals a PID it can read,
        # so publishing the PID first opens a window where an early keypress
        # delivers SIGUSR1 with no handler installed — whose default action is
        # to terminate the process.
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1,
                             lambda: (panel.show(), True)[1])
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR2,
                             lambda: (panel.hide(), True)[1])

        with open(PID_FILE, "w", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))

        refresh_timetable_async()
        GLib.timeout_add_seconds(REFRESH_INTERVAL_S, refresh_timetable_async)

        panel.alert_tick()      # seed alert_last so past prayers stay silent
        GLib.timeout_add_seconds(ALERT_TICK_S, panel.alert_tick)

        log(f"ready, pid {os.getpid()}")

    app.connect("activate", on_activate)
    try:
        return app.run([])
    finally:
        if not oneshot:
            try:
                os.unlink(PID_FILE)
            except OSError:
                pass


if __name__ == "__main__":
    sys.exit(main())
