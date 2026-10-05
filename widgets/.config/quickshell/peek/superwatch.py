#!/usr/bin/env python3
"""Print "down" / "up" as SUPER is physically pressed / released.
With --shift, also print "shift down" / "shift up" for the Shift keys.

Read straight from evdev (user is in the `input` group) instead of Hyprland
binds, which drop ~9% of release events and would strand the bar on screen.
keyd grabs the physical keyboards, so its virtual keyboard carries the events;
every device that can send SUPER is watched, so this also works without keyd.
Spawned by shell.qml; exits when its stdout closes.
"""
import glob
import os
import select
import struct
import sys
import time

KEY_LEFTMETA, KEY_RIGHTMETA = 125, 126
KEY_LEFTSHIFT, KEY_RIGHTSHIFT = 42, 54
WATCH_SHIFT = "--shift" in sys.argv[1:]
EV_KEY = 1
EVENT = struct.Struct("llHHi")      # struct input_event
RESCAN_SECS = 5.0                   # pick up hotplugged keyboards


def keyboards():
    # Any device that can send SUPER, whatever it's called: wireless receivers
    # put their main keyboard on an interface named after the dongle (e.g.
    # "Compx 2.4G Wireless Receiver"), not "... Keyboard".
    out = []
    for caps_file in glob.glob("/sys/class/input/event*/device/capabilities/key"):
        try:
            with open(caps_file) as f:
                words = f.read().split()
        except OSError:
            continue
        bits, width = 0, struct.calcsize("l") * 8   # sysfs prints longs, highest first
        for w in words:
            bits = (bits << width) | int(w, 16)
        if bits >> KEY_LEFTMETA & 1 or bits >> KEY_RIGHTMETA & 1:
            out.append("/dev/input/" + caps_file.split("/")[4])
    return out


def main():
    fds, down, held, last_scan = {}, set(), False, 0.0
    shift_down, shift_held = set(), False
    while True:
        if time.monotonic() - last_scan > RESCAN_SECS:
            paths = set(keyboards())
            for p in list(fds):
                if p not in paths:
                    fd = fds.pop(p)
                    down = {k for k in down if k[0] != fd}
                    shift_down = {k for k in shift_down if k[0] != fd}
                    os.close(fd)
            for p in paths - set(fds):
                try:
                    fds[p] = os.open(p, os.O_RDONLY | os.O_NONBLOCK)
                except OSError:
                    pass
            last_scan = time.monotonic()

        ready, _, _ = select.select(list(fds.values()), [], [], RESCAN_SECS)
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except BlockingIOError:
                continue
            except OSError:          # unplugged; dropped on next rescan
                last_scan = 0.0
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, typ, code, value = EVENT.unpack_from(data, i)
                if typ == EV_KEY and code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                    if value == 0:
                        down.discard((fd, code))
                    elif value == 1:
                        down.add((fd, code))
                elif WATCH_SHIFT and typ == EV_KEY and code in (KEY_LEFTSHIFT, KEY_RIGHTSHIFT):
                    if value == 0:
                        shift_down.discard((fd, code))
                    elif value == 1:
                        shift_down.add((fd, code))

        try:
            if WATCH_SHIFT and bool(shift_down) != shift_held:
                shift_held = bool(shift_down)
                print("shift down" if shift_held else "shift up", flush=True)
            if bool(down) != held:
                held = bool(down)
                print("down" if held else "up", flush=True)
        except BrokenPipeError:
            sys.exit(0)


if __name__ == "__main__":
    main()
