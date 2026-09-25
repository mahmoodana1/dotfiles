#!/usr/bin/env python3
"""Print one JSON line per desktop notification, for the Dynamic Island.

Eavesdrops on org.freedesktop.Notifications.Notify with dbus-monitor, so
swaync stays the real notification daemon (history, panel, actions).
OSD-style notifications (volume/brightness level popups) are marked
"osd": true; the island shows those natively instead.
"""
import json
import re
import subprocess
import sys

MATCH = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
ARG = re.compile(r"^   (string|uint32|int32|int64|array|byte|boolean|double) ?(.*)$")
OSD_HINTS = ("x-canonical-private-synchronous", "SWAYNC_BYPASS_DND")


def parse(block):
    """block: lines after the 'method call' header -> dict or None"""
    args, cur = [], None
    for line in block:
        m = ARG.match(line)
        if m:
            cur = [m.group(1), m.group(2)]
            args.append(cur)
        elif cur is not None:
            cur[1] += "\n" + line

    def s(i):
        if i >= len(args) or args[i][0] != "string":
            return ""
        v = args[i][1]
        return v[1:-1] if v.startswith('"') and v.endswith('"') else v

    if len(args) < 7:
        return None
    hints = args[6][1] if args[6][0] == "array" else ""
    urgency = re.search(r'string "urgency"\s+variant\s+byte (\d)', hints)
    return {
        "app": s(0),
        "icon": s(2),
        "summary": s(3),
        "body": s(4),
        "urgency": int(urgency.group(1)) if urgency else 1,
        "osd": any(h in hints for h in OSD_HINTS) or '"value"' in hints,
    }


def main():
    proc = subprocess.Popen(["dbus-monitor", "--session", MATCH],
                            stdout=subprocess.PIPE, text=True, bufsize=1)
    block, inside = [], False
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line.startswith(("method call", "signal", "method return", "error")):
            if inside and block:
                emit(block)
            inside = line.startswith("method call") and "member=Notify" in line
            block = []
        elif inside:
            block.append(line)
            # expire_timeout (8th arg, int32) ends a Notify call: emit now
            # rather than waiting for the next bus message
            if line.startswith("   int32 ") and sum(1 for l in block if ARG.match(l)) >= 8:
                emit(block)
                inside, block = False, []
    if inside and block:
        emit(block)


def emit(block):
    n = parse(block)
    if n:
        try:
            print(json.dumps(n), flush=True)
        except BrokenPipeError:
            sys.exit(0)


if __name__ == "__main__":
    main()
