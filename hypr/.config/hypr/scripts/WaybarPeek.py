#!/usr/bin/env python3
"""Auto-hide driver for the "[TOP] Peek" waybar layout.

Shows the bar when:
  * the workspace changes      -> brief flash (FLASH_SECS)
  * SUPER is held              -> after HOLD_DELAY, until release (capped at HOLD_MAX)
  * the pointer hits the top   -> edge reveal, then stays while the pointer is over the bar

Inert unless ~/.config/waybar/config points at the Peek layout, so it is safe to
leave autostarted with any other layout.

Signals: USR1 = SUPER pressed, USR2 = SUPER released (sent by WaybarPeek.sh).

Waybar only offers a *toggle* (SIGUSR1). Rather than trusting a remembered
state, the real state is read from Hyprland: a hidden waybar is moved to the
bottom layer (level < 2), a shown one sits on top/overlay (level >= 2).
"""
import json
import os
import signal
import socket
import sys
import threading
import time

FLASH_SECS = 1.2     # workspace-change flash
HOLD_DELAY = 0.35    # SUPER must be held this long (skips quick SUPER+key chords)
HOLD_MAX = 6.0       # safety cap: Hyprland drops some release events
EDGE_PX = 2          # pointer this close to the top edge reveals the bar
EDGE_DWELL = 0.25    # ...after resting there this long
BAR_ZONE_PX = 40     # pointer above this y keeps a shown bar open (margin+height)
TICK = 0.1
RESYNC_SECS = 1.0

HOME = os.path.expanduser("~")
WAYBAR_CONFIG = os.path.join(HOME, ".config/waybar/config")
PEEK_NAME = "[TOP] Peek"
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PID_FILE = os.path.join(RUNTIME, "waybar-peek.pid")
HYPR_DIR = os.path.join(RUNTIME, "hypr", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))

# Events that mean "SUPER was part of a chord", which cancels a pending hold.
CHORD_EVENTS = {"openwindow", "closewindow", "openlayer", "movewindowv2",
                "changefloatingmode", "fullscreen", "togglegroup", "submap"}


def enabled():
    try:
        return os.path.basename(os.readlink(WAYBAR_CONFIG)) == PEEK_NAME
    except OSError:
        return False


def hypr(cmd):
    """Query Hyprland's command socket (no hyprctl process spawn)."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        s.connect(os.path.join(HYPR_DIR, ".socket.sock"))
        s.sendall(cmd.encode())
        chunks = []
        while True:
            b = s.recv(65536)
            if not b:
                break
            chunks.append(b)
    return b"".join(chunks)


def waybar_state():
    """-> (pid, visible) of the running waybar, or (None, None)."""
    layers = json.loads(hypr("j/layers"))
    for mon in layers.values():
        for level, surfaces in mon["levels"].items():
            for l in surfaces:
                if l["namespace"] == "waybar":
                    return l["pid"], int(level) >= 2
    return None, None


def cursor_y():
    return json.loads(hypr("j/cursorpos"))["y"]


class Peek:
    def __init__(self):
        self.lock = threading.Lock()
        self.flash_until = 0.0
        self.hold_since = None      # SUPER press time, None when released
        self.edge_since = None
        self.hovering = False
        self.want = False
        self.last_sync = 0.0

    # --- inputs -----------------------------------------------------------
    def on_press(self, *_):
        with self.lock:
            if self.hold_since is None:
                self.hold_since = time.monotonic()

    def on_release(self, *_):
        with self.lock:
            self.hold_since = None

    def on_event(self, name):
        with self.lock:
            # focusedmonv2 covers jumping to a workspace already shown on another monitor
            if name in ("workspacev2", "focusedmonv2"):
                self.flash_until = time.monotonic() + FLASH_SECS
            elif name in CHORD_EVENTS and self.hold_since is not None \
                    and time.monotonic() - self.hold_since < HOLD_DELAY:
                self.hold_since = None

    # --- loop -------------------------------------------------------------
    def compute(self, now):
        with self.lock:
            held = self.hold_since is not None and HOLD_DELAY <= now - self.hold_since < HOLD_MAX
            if self.hold_since is not None and now - self.hold_since >= HOLD_MAX:
                self.hold_since = None
            flashing = now < self.flash_until
        y = cursor_y()
        if y <= EDGE_PX:
            self.edge_since = self.edge_since or now
        else:
            self.edge_since = None
        edge = self.edge_since is not None and now - self.edge_since >= EDGE_DWELL
        # Hover only holds a bar that is already up; it never opens one.
        self.hovering = self.want and y < BAR_ZONE_PX
        return held or flashing or edge or self.hovering

    def apply(self, want, now):
        if want == self.want and now - self.last_sync < RESYNC_SECS:
            return
        self.want, self.last_sync = want, now
        pid, visible = waybar_state()
        if pid is not None and visible != want:
            os.kill(pid, signal.SIGUSR1)

    def run(self):
        while True:
            now = time.monotonic()
            try:
                if enabled():
                    self.apply(self.compute(now), now)
                else:
                    self.want = False
            except (OSError, ValueError, KeyError):
                pass  # Hyprland/waybar restarting; retry next tick
            time.sleep(TICK)


def listen_events(peek):
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(os.path.join(HYPR_DIR, ".socket2.sock"))
                buf = b""
                while True:
                    data = s.recv(4096)
                    if not data:
                        break
                    buf += data
                    *lines, buf = buf.split(b"\n")
                    for line in lines:
                        peek.on_event(line.split(b">>", 1)[0].decode(errors="replace"))
        except OSError:
            pass
        time.sleep(1)


def single_instance():
    try:
        with open(PID_FILE) as f:
            old = int(f.read().strip())
        os.kill(old, 0)
        with open(f"/proc/{old}/cmdline", "rb") as f:
            if b"WaybarPeek.py" in f.read():
                sys.exit(0)
    except (OSError, ValueError):
        pass
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def main():
    single_instance()
    peek = Peek()
    signal.signal(signal.SIGUSR1, peek.on_press)
    signal.signal(signal.SIGUSR2, peek.on_release)
    threading.Thread(target=listen_events, args=(peek,), daemon=True).start()
    peek.run()


if __name__ == "__main__":
    main()
