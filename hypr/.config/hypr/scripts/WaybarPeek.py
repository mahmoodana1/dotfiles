#!/usr/bin/env python3
"""Hold-SUPER driver for the "[TOP] Peek" waybar layout.

The bar is visible exactly while a SUPER key is physically held. Key state is
read straight from evdev (user is in the `input` group) instead of Hyprland
binds, which drop ~9% of release events and would strand the bar on screen.
keyd grabs the physical keyboards, so its virtual keyboard carries the events;
every keyboard-like device is watched, so this also works without keyd.

Inert unless ~/.config/waybar/config points at the Peek layout.

Waybar only offers a *toggle* (SIGUSR1). The real state is read from Hyprland:
a hidden waybar is moved to the bottom layer (level < 2), a shown one sits on
top/overlay (level >= 2).
"""
import glob
import json
import os
import select
import signal
import socket
import struct
import sys
import time

KEY_LEFTMETA, KEY_RIGHTMETA = 125, 126
EV_KEY = 1
EVENT = struct.Struct("llHHi")      # struct input_event
RESYNC_SECS = 1.0                   # re-check real bar state (manual toggles, waybar restarts)
RESCAN_SECS = 5.0                   # pick up hotplugged keyboards

HOME = os.path.expanduser("~")
WAYBAR_CONFIG = os.path.join(HOME, ".config/waybar/config")
PEEK_NAME = "[TOP] Peek"
NAMESPACE = "peek"                  # from "name" in the Peek config
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PID_FILE = os.path.join(RUNTIME, "waybar-peek.pid")
HYPR_DIR = os.path.join(RUNTIME, "hypr", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))


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


def set_visible(want):
    for mon in json.loads(hypr("j/layers")).values():
        for level, surfaces in mon["levels"].items():
            for l in surfaces:
                if l["namespace"] == NAMESPACE:
                    if (int(level) >= 2) != want:
                        os.kill(l["pid"], signal.SIGUSR1)
                    return


def keyboards():
    """event device paths whose name looks like a keyboard."""
    out = []
    for name_file in glob.glob("/sys/class/input/event*/device/name"):
        with open(name_file) as f:
            if "keyboard" in f.read().lower():
                out.append("/dev/input/" + name_file.split("/")[4])
    return out


class Peek:
    def __init__(self):
        self.fds = {}        # path -> fd
        self.down = set()    # (fd, keycode) of held SUPER keys
        self.last_scan = 0.0

    def rescan(self):
        paths = set(keyboards())
        for p in list(self.fds):
            if p not in paths:
                self.close(p)
        for p in paths - set(self.fds):
            try:
                self.fds[p] = os.open(p, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                pass
        self.last_scan = time.monotonic()

    def close(self, path):
        fd = self.fds.pop(path)
        self.down = {k for k in self.down if k[0] != fd}
        os.close(fd)

    def read(self, fd):
        try:
            data = os.read(fd, EVENT.size * 64)
        except BlockingIOError:
            return
        except OSError:          # unplugged
            path = next(p for p, f in self.fds.items() if f == fd)
            self.close(path)
            return
        for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
            _, _, typ, code, value = EVENT.unpack_from(data, i)
            if typ == EV_KEY and code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                if value == 0:
                    self.down.discard((fd, code))
                elif value == 1:
                    self.down.add((fd, code))

    def run(self):
        shown, last_sync = None, 0.0
        while True:
            now = time.monotonic()
            if now - self.last_scan > RESCAN_SECS:
                self.rescan()
            ready, _, _ = select.select(list(self.fds.values()), [], [], RESYNC_SECS)
            for fd in ready:
                self.read(fd)
            want = bool(self.down)
            now = time.monotonic()
            if want != shown or now - last_sync > RESYNC_SECS:
                try:
                    if enabled():
                        set_visible(want)
                    shown, last_sync = want, now
                except (OSError, ValueError, KeyError):
                    pass  # Hyprland/waybar restarting; retry next pass


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


if __name__ == "__main__":
    single_instance()
    Peek().run()
