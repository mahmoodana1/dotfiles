"""Palette parsing and CSS assembly. Pure logic — imports no GTK."""

import re
from pathlib import Path

# Matches:  name       = "rgb(RRGGBB)",
_COLOR_RE = re.compile(r'^\s*(\w+)\s*=\s*"rgb\(([0-9A-Fa-f]{6})\)"', re.MULTILINE)

# Used when colors.lua is missing or unparseable. Neutral dark, readable.
FALLBACK = {
    "background": "#11121A",
    "foreground": "#E1E4E9",
    "color0": "#11121A",
    "color7": "#CCD0D7",
    "color8": "#8F9196",
}


def load_palette_text(path) -> str:
    """Read colors.lua. Returns '' if it is missing or unreadable."""
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError:
        return ""


def parse_palette(text: str) -> dict:
    """Extract {name: '#RRGGBB'} from wallust's colors.lua text."""
    return {name: "#" + value.upper() for name, value in _COLOR_RE.findall(text)}


def build_css(palette_text: str, css_body: str) -> str:
    """Prepend @define-color declarations to the stylesheet body."""
    palette = parse_palette(palette_text) or dict(FALLBACK)
    for name, value in FALLBACK.items():
        palette.setdefault(name, value)
    defs = "\n".join(f"@define-color {n} {v};" for n, v in sorted(palette.items()))
    return f"{defs}\n\n{css_body}"
