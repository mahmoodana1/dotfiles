#!/usr/bin/env python3
"""Claude Code status line: live Claude glyph, session info to its left.

Two DIFFERENT percentages are shown, because they measure different things:
  ctx     = context_window.used_percentage  -> how full THIS conversation is
  5h / 7d = rate_limits.*.used_percentage   -> plan limits (what /usage reports),
            each annotated with time remaining until the window resets.

Glyph: the eyes live INSIDE the head -- two cells of the face row rendered in a
dark tone. Blinking recolours those cells toward the face colour, so the mark's
shape is never altered. The bottom row is legs and stays put. Cells are shaded
by row and column for a soft light-from-upper-left depth.

Layout: the glyph is anchored a fixed gap past the widest text row, and every
row carries left-hand content, so alignment comes from computed interior padding
rather than leading whitespace (which a renderer may trim). Rows are all
newline-terminated: a final row without one is not rendered. RESERVE keeps the
block clear of the interface's own left/right spacing.

Animation runs at 1 fps -- Claude Code enforces a 1s minimum on refreshInterval.
Schema: docs.claude.com/en/docs/claude-code/statusline
"""
import json
import os
import re
import sys
import time

RESET = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"
BLUE = "\033[1;34m"
RED = "\033[31m"
YELLOW = "\033[33m"
GREEN = "\033[32m"

TRUECOLOR = os.environ.get("COLORTERM", "") in ("truecolor", "24bit")

BASE = (217, 119, 87)     # Claude terracotta #D97757
FALLBACK = "\033[38;5;173m"

# Soft light from the upper left: each row/column step darkens slightly.
ROW_STEP = 0.10
COL_STEP = 0.022
FLOOR = 0.60

# Glyph rows, verbatim, with their natural relative indents.
# Field is 11 wide (2 cols of slack) so the head can sway +/-1 without clipping.
FIELD = 11
# The eyes are already in the mark: the empty quadrant of '▛' and of '▜' form
# two symmetric holes in the head. Blinking fills exactly those two quadrants by
# swapping both cells to '█' -- no characters are added and the width is
# unchanged. Confirmed by expanding each cell to its 2x2 quadrants.
# Gaze shifts the holes one quadrant by swapping which of '▛'/'▜'/'█' occupies
# the cell -- all three already appear in the mark, so no character is added and
# the head outline (upper half) is byte-identical in every frame.
TOP = "▐▛███▜▌"      # 7 cols, rests at x=2 -- eyes centred (quadrants 3, 10)
TOP_LEFT = "▐▜██▛█▌" # eyes left  (quadrants 2, 9)
TOP_RIGHT = "▐█▜██▛▌"  # eyes right (quadrants 4, 11)
TOP_SHUT = "▐█████▌" # eye holes filled -- blink
MID = "▝▜█████▛▘"    # 9 cols, rests at x=1 -- body
LEGS = "▘▘ ▝▝"       # 5 cols, rests at x=3 -- legs; never blink

GAP = 3              # columns between the text block and the glyph
RESERVE = 6          # columns left free for the interface's own spacing
CYCLE = 20           # seconds per full animation loop

# One single blink, then a double, so the rhythm reads as organic rather than
# metronomic. The eye holes are a single quadrant each, so there is no partial
# state to render -- a blink is one frame, open to shut to open.
BLINKS = frozenset((6, 14, 16))
# A held glance left, then a deliberate left-to-right sweep across f8..f11.
GAZE_LEFT = frozenset((3, 4, 8))
GAZE_RIGHT = frozenset((10, 11))
SWAY_RIGHT = frozenset((12, 13))
SWAY_LEFT = frozenset((18, 19))

ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def vis(s):
    """Visible width, ignoring ANSI colour codes."""
    return len(ANSI_RE.sub("", s))


def hue(v):
    return RED if v >= 80 else YELLOW if v >= 50 else GREEN


def rgb(c):
    return "\033[38;2;%d;%d;%dm" % c


def shade(color, row, col):
    """Darken `color` by its position: light comes from the upper left."""
    if not TRUECOLOR:
        return FALLBACK
    f = max(FLOOR, 1.0 - ROW_STEP * row - COL_STEP * col)
    return rgb(tuple(int(v * f) for v in color))


def place(art, x):
    """Drop `art` at column x inside a FIELD-wide row, clamped in bounds."""
    x = max(0, min(FIELD - len(art), x))
    return " " * x + art + " " * (FIELD - x - len(art))


def paint(row_art, row_idx):
    """Colour a placed row with the positional shading."""
    out, prev = [], None
    for c, ch in enumerate(row_art):
        if ch == " ":
            out.append(" ")
            prev = None
            continue
        color = shade(BASE, row_idx, c)
        if color != prev:
            out.append(color)
            prev = color
        out.append(ch)
    out.append(RESET)
    return "".join(out)


def animate(t):
    """Return the three glyph rows for second `t`."""
    f = t % CYCLE
    sway = 1 if f in SWAY_RIGHT else -1 if f in SWAY_LEFT else 0
    head = (TOP_SHUT if f in BLINKS          # shut wins: no gaze while blinking
            else TOP_LEFT if f in GAZE_LEFT
            else TOP_RIGHT if f in GAZE_RIGHT
            else TOP)
    return [
        paint(place(head, 2 + sway), 0),
        paint(place(MID, 1 + sway), 1),
        paint(place(LEGS, 3 + sway), 2),
    ]


def countdown(secs):
    """Compact 'time remaining' string."""
    if secs <= 0:
        return "now"
    d, rem = divmod(int(secs), 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return "%dd%dh" % (d, h)
    if h:
        return "%dh%02dm" % (h, m)
    return "%dm" % max(m, 1)


def main():
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            data = {}
    except Exception:
        data = {}

    def dig(*path, default=None):
        cur = data
        for k in path:
            if not isinstance(cur, dict):
                return default
            cur = cur.get(k)
        return default if cur is None else cur

    now = time.time()

    model = dig("model", "display_name", default="unknown") or "unknown"

    try:
        pct = max(0, min(100, int(float(dig("context_window", "used_percentage",
                                            default=0) or 0))))
    except (TypeError, ValueError):
        pct = 0

    def window(name):
        """(used_percentage, seconds_until_reset) for a rate-limit window."""
        v = dig("rate_limits", name, "used_percentage")
        try:
            used = max(0, min(100, int(float(v))))
        except (TypeError, ValueError):
            return None
        try:
            left = float(dig("rate_limits", name, "resets_at")) - now
        except (TypeError, ValueError):
            left = None
        return used, left

    five, week = window("five_hour"), window("seven_day")

    d = dig("workspace", "current_dir", default="") or os.getcwd()
    home = os.path.expanduser("~")
    if d == home:
        d = "~"
    elif d.startswith(home + os.sep):
        d = "~" + d[len(home):]

    filled = max(0, min(10, pct // 10))
    bar = "█" * filled + "░" * (10 - filled)

    # --- rows: (plain, coloured) so widths can be measured before padding ---
    r0 = (d, "%s%s%s" % (BLUE, d, RESET))

    r1_plain = "%s  ctx [%s] %d%%" % (model, bar, pct)
    r1 = (r1_plain, "%s%s%s  %sctx%s %s[%s]%s %s%d%%%s"
          % (BOLD, model, RESET, DIM, RESET, hue(pct), bar, RESET, DIM, pct, RESET))

    seg_plain, seg_col = [], []
    for label, w in (("5h", five), ("7d", week)):
        if w is None:
            continue
        used, left = w
        tail = "" if left is None else " %s" % countdown(left)
        seg_plain.append("%s %d%%%s" % (label, used, tail))
        seg_col.append("%s%s%s %s%d%%%s%s"
                       % (DIM, label, RESET, hue(used), used, RESET,
                          "" if not tail else "%s%s%s" % (DIM, tail, RESET)))
    if seg_plain:
        r2 = ("  ".join(seg_plain), "  ".join(seg_col))
    else:
        r2 = ("plan limits n/a", "%splan limits n/a%s" % (DIM, RESET))

    rows = [r0, r1, r2]

    # --- terminal width: Claude Code sets COLUMNS; stdout is captured, not a tty ---
    try:
        cols = int(os.environ.get("COLUMNS", "80"))
    except ValueError:
        cols = 80

    # The interface adds its own left/right spacing around the status line, so
    # filling all of COLUMNS overflows and the renderer ellipsizes the tail.
    usable = cols - RESERVE

    show_glyph = usable >= FIELD + 12
    budget = usable - (FIELD + GAP) if show_glyph else usable

    # Trim over-long left content (path from the left, others from the right)
    out = []
    for i, (plain, colored) in enumerate(rows):
        if budget > 3 and len(plain) > budget:
            if i == 0:
                plain = "…" + plain[-(budget - 1):]
                colored = "%s%s%s" % (BLUE, plain, RESET)
            else:
                plain = plain[: budget - 1] + "…"
                colored = "%s%s%s" % (DIM, plain, RESET)
        out.append((plain, colored))

    if not show_glyph:
        for _, colored in out:
            print(colored)
        return

    # Anchor the glyph just past the widest row rather than at the terminal
    # edge: keeps it visually attached to the text and clear of the margins.
    glyph = animate(int(now))
    start = min(max(len(p) for p, _ in out) + GAP, usable - FIELD)
    for (plain, colored), g in zip(out, glyph):
        print("%s%s%s" % (colored, " " * max(1, start - len(plain)), g))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("%s%s%s" % (DIM, MID, RESET))
