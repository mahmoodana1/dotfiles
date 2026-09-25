#!/usr/bin/env python3
"""Signal strength of connected Bluetooth devices, for the floating BT panel.

Prints one JSON line per second: {"AA:BB:..": -48, "CC:DD:..": null}
RSSI in dBm via blueman's HCI conn-info reader (no root needed). LE devices
can't be read that way without root, so they come out null.
Runs only while the floating panel is open.
"""
import json
import subprocess
import sys
import time

from _blueman import ConnInfoReadError, conn_info


def connected():
    out = subprocess.run(["bluetoothctl", "devices", "Connected"],
                         capture_output=True, text=True, timeout=3).stdout
    return [line.split()[1] for line in out.splitlines() if line.startswith("Device ")]


def rssi(addr):
    ci = conn_info(addr, "hci0")
    try:
        ci.init()
        return ci.get_rssi()
    except ConnInfoReadError:
        return None
    finally:
        try:
            ci.deinit()
        except Exception:
            pass


while True:
    try:
        print(json.dumps({a: rssi(a) for a in connected()}), flush=True)
    except BrokenPipeError:          # panel closed; before OSError (its parent)
        sys.exit(0)
    except (subprocess.SubprocessError, OSError):
        pass
    time.sleep(1)
