"""The HUD's content as JSON, for the glass HUD (quickshell/glass/Hud.qml).

payload() turns timetable.schedule() into display-ready strings, with the same
priorities the panel always had:
  1. What do I need to do next, and how long have I got?
  2. The full day's adhan and iqama times, aligned so they can't be misread.
  3. Everything else (clock, dates, source) stays quiet.
Adhan and iqama stay separate fields because confusing them is the one error
that actually costs you a prayer.
"""
import json
import os
import tempfile

import prayer
import timetable

LOCATION = "Wadi al-Joz, Jerusalem"
# Sunrise is not a prayer, but it closes the Fajr window, so it earns a line.
ROW_ORDER = ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")


def _hero(schedule: dict) -> dict:
    """The single most useful line: what is imminent."""
    if schedule["in_iqama_window"]:
        # Adhan has been called; the congregation is forming.
        name = schedule["current_prayer"]
        return {
            "urgent": True,
            "caption": "IQAMA IN",
            "arabic": prayer.ARABIC_NAMES[name],
            "big": prayer.format_countdown(schedule["until_iqama"]),
            "detail": (f"{prayer.DISPLAY_NAMES[name]} {schedule['times'][name]:%H:%M}"
                       f"  →  iqama {schedule['iqamas'][name]:%H:%M}"),
        }
    name = schedule["next_prayer"]
    return {
        "urgent": False,
        "caption": "NEXT" + (" (tomorrow)" if schedule["next_is_tomorrow"] else ""),
        "arabic": prayer.ARABIC_NAMES[name],
        "big": prayer.format_countdown(schedule["until_next"]),
        "detail": (f"{prayer.DISPLAY_NAMES[name]} {schedule['next_time']:%H:%M}"
                   f"  →  iqama {schedule['next_iqama']:%H:%M}"),
    }


def _rows(schedule: dict) -> list:
    rows = []
    for name in ROW_ORDER:
        when = schedule["times"][name]
        if name == "sunrise":
            # Not a prayer: no iqama, drawn as a quiet divider.
            rows.append({"name": prayer.DISPLAY_NAMES[name], "arabic": "",
                         "adhan": f"{when:%H:%M}", "iqama": "—", "state": "sunrise"})
            continue
        is_next = (name == schedule["next_prayer"]
                   and not schedule["in_iqama_window"]
                   and not schedule["next_is_tomorrow"])
        is_active = schedule["in_iqama_window"] and name == schedule["current_prayer"]
        is_past = when <= schedule["now"] and not is_active
        state = "live" if (is_next or is_active) else "past" if is_past else "normal"
        rows.append({"name": prayer.DISPLAY_NAMES[name], "arabic": prayer.ARABIC_NAMES[name],
                     "adhan": f"{when:%H:%M}", "iqama": f"{schedule['iqamas'][name]:%H:%M}",
                     "state": state})
    return rows


def payload(schedule: dict) -> dict:
    now = schedule["now"]
    dates = f"{now:%a %d %b %Y}"
    if schedule.get("hijri"):
        dates += f"   ·   {schedule['hijri']}"
    return {
        "generated": int(now.timestamp()),
        "clock": f"{now:%H:%M}",
        "dates": dates,
        "location": LOCATION,
        # Never let the fallback masquerade as the published timetable.
        "fallback": schedule.get("source") != timetable.SOURCE_OFFICIAL,
        "hero": _hero(schedule),
        "rows": _rows(schedule),
    }


def write_atomic(path: str, data: dict) -> None:
    """Write JSON so a reader never sees a half-written file."""
    directory = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".hud-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
