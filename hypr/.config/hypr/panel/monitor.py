"""Focused-monitor resolution. Pure logic — imports no GTK."""

import json
import subprocess


def focused_connector(hyprctl_json: str):
    """Return the focused monitor's connector name, or None."""
    try:
        monitors = json.loads(hyprctl_json)
    except (ValueError, TypeError):
        return None
    if not isinstance(monitors, list):
        return None
    for entry in monitors:
        if isinstance(entry, dict) and entry.get("focused") is True:
            name = entry.get("name")
            return name if isinstance(name, str) else None
    return None


def query_focused_connector():
    """Ask Hyprland which monitor has focus. Returns None on any failure."""
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, timeout=1.0,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return focused_connector(result.stdout)
