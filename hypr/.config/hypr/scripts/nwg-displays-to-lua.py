#!/usr/bin/env python3
"""Convert nwg-displays output into the Lua config format.

nwg-displays can only write the legacy .conf format. It writes
  ~/.config/hypr/monitors.conf    (monitor= lines)
  ~/.config/hypr/workspaces.conf  (workspace= lines)

Hyprland 0.57+ reads Lua only, so this regenerates
  ~/.config/hypr/lua/monitors.lua
  ~/.config/hypr/lua/workspaces.lua

Run it after clicking Apply in nwg-displays, then `hyprctl reload`.
The wrapper scripts/nwg-displays.sh does both for you.
"""
import re
import sys
from pathlib import Path

HYPR = Path.home() / ".config/hypr"
LUA = HYPR / "lua"

HEADER = (
    "-- Generated from {src} by scripts/nwg-displays-to-lua.py\n"
    "-- Do not edit by hand: re-running nwg-displays overwrites this file.\n\n"
)


def parse_kv_lines(path: Path, keyword: str):
    """Yield the value part of `keyword = ...` lines, ignoring comments."""
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.match(r"^%s\s*=\s*(.+)$" % keyword, line)
        if m:
            yield m.group(1).strip()


def lua_str(s: str) -> str:
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def convert_monitors() -> str:
    src = HYPR / "monitors.conf"
    out = [HEADER.format(src=src.name)]
    count = 0

    for val in parse_kv_lines(src, "monitor"):
        parts = [p.strip() for p in val.split(",")]
        name = parts[0]

        # `monitor = NAME, disable`
        if len(parts) >= 2 and parts[1].lower() in ("disable", "disabled"):
            out.append("hl.monitor({ output = %s, disabled = true })" % lua_str(name))
            count += 1
            continue

        if len(parts) < 4:
            out.append("-- skipped unrecognised line: monitor=%s" % val)
            continue

        mode, position, scale = parts[1], parts[2], parts[3]
        fields = [
            "output = %s" % lua_str(name),
            "mode = %s" % lua_str(mode),
            "position = %s" % lua_str(position),
        ]
        # scale may be "1" or "auto"
        try:
            fields.append("scale = %s" % float(scale))
        except ValueError:
            fields.append("scale = %s" % lua_str(scale))

        # trailing key/value pairs: mirror, bitdepth, transform, vrr, ...
        extra = parts[4:]
        i = 0
        while i + 1 < len(extra) + 1 and i < len(extra):
            key = extra[i].lower()
            if key in ("mirror", "bitdepth", "transform", "vrr", "cm", "sdrbrightness",
                       "sdrsaturation") and i + 1 < len(extra):
                v = extra[i + 1]
                try:
                    fields.append("%s = %s" % (key, int(v)))
                except ValueError:
                    fields.append("%s = %s" % (key, lua_str(v)))
                i += 2
            else:
                i += 1

        out.append("hl.monitor({ %s })" % ", ".join(fields))
        count += 1

    if count == 0:
        out.append("-- no monitors configured; Hyprland will auto-detect")
    return "\n".join(out) + "\n"


def convert_workspaces() -> str:
    src = HYPR / "workspaces.conf"
    out = [HEADER.format(src=src.name)]
    count = 0

    for val in parse_kv_lines(src, "workspace"):
        parts = [p.strip() for p in val.split(",")]
        ws = parts[0]
        fields = ["workspace = %s" % lua_str(ws)]

        for rule in parts[1:]:
            if ":" not in rule:
                continue
            key, _, v = rule.partition(":")
            key, v = key.strip(), v.strip()
            # normalise legacy rule names to the Lua field names
            key = {
                "gapsin": "gaps_in",
                "gapsout": "gaps_out",
                "bordersize": "border_size",
                "border": "no_border",
                "rounding": "no_rounding",
                "on-created-empty": "on_created_empty",
                "defaultName": "default_name",
            }.get(key, key)

            if key in ("no_border", "no_rounding"):
                # legacy `border:false` means "no border"
                fields.append("%s = %s" % (key, "true" if v.lower() in ("false", "0") else "false"))
            elif v.lower() in ("true", "false"):
                fields.append("%s = %s" % (key, v.lower()))
            else:
                try:
                    fields.append("%s = %s" % (key, int(v)))
                except ValueError:
                    fields.append("%s = %s" % (key, lua_str(v)))

        out.append("hl.workspace_rule({ %s })" % ", ".join(fields))
        count += 1

    if count == 0:
        out.append("-- no workspace rules configured")
    return "\n".join(out) + "\n"


def main() -> int:
    LUA.mkdir(parents=True, exist_ok=True)
    (LUA / "monitors.lua").write_text(convert_monitors(), encoding="utf-8")
    (LUA / "workspaces.lua").write_text(convert_workspaces(), encoding="utf-8")
    print("wrote lua/monitors.lua and lua/workspaces.lua")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
