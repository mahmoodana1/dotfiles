#!/usr/bin/env python3
"""Print SUPER / Shift key state as it changes: "super 1", "super 0",
"shift 1", "shift 0". Reads evdev directly (user in `input`): Hyprland binds
miss some releases, which would leave the island stuck open. Watches every
device that can send SUPER (keyd's virtual keyboard included) and rescans
for hotplugged ones. Exits when stdout closes (Quickshell went away).
"""
import glob
import os
import select
import struct
import sys
import time

META = (125, 126)            # KEY_LEFTMETA, KEY_RIGHTMETA
SHIFT = (42, 54)             # KEY_LEFTSHIFT, KEY_RIGHTSHIFT
EVENT = struct.Struct("llHHi")
EV_KEY = 1


def can_send_super(event_path):
    name = os.path.basename(event_path)
    try:
        with open(f"/sys/class/input/{name}/device/capabilities/key") as f:
            words = f.read().split()
    except OSError:
        return False
    # bitmap printed as hex words, most significant first, 64 bits each
    bits = int("".join(w.zfill(16) for w in words), 16)
    return bool(bits >> META[0] & 1)


def open_keyboards(known):
    for path in glob.glob("/dev/input/event*"):
        if path in known.values() or not can_send_super(path):
            continue
        try:
            known[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = path
        except OSError:
            pass


def say(line):
    try:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        sys.exit(0)


def main():
    fds = {}
    pressed = set()
    state = {"super": False, "shift": False}
    next_scan = 0.0
    while True:
        now = time.monotonic()
        if now >= next_scan:
            open_keyboards(fds)
            next_scan = now + 5
        ready, _, _ = select.select(list(fds), [], [], 5)
        for fd in ready:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:            # unplugged
                os.close(fd)
                fds.pop(fd, None)
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, etype, code, value = EVENT.unpack_from(data, i)
                if etype != EV_KEY or value == 2 or code not in META + SHIFT:
                    continue
                key = (fd, code)
                pressed.add(key) if value else pressed.discard(key)
                for name, codes in (("super", META), ("shift", SHIFT)):
                    on = any(c in codes for _, c in pressed)
                    if on != state[name]:
                        state[name] = on
                        say(f"{name} {int(on)}")


if __name__ == "__main__":
    main()
