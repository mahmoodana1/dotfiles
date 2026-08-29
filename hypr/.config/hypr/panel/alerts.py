"""Prayer-time notifications. Pure event logic + dispatch, no GTK.

Fires a desktop notification and the message-new-instant sound at each adhan
and each iqama.

Deliberately driven by a periodic tick rather than one timer per event.
A timer scheduled hours ahead does not survive suspend/resume or a DST change
cleanly; re-deriving "what became due since I last looked" from wall-clock time
does. The same mechanism handles the day rollover and a timetable refresh for
free.
"""

import shutil
import subprocess
from datetime import timedelta

import prayer

# Set to False if you only want the adhan and not the iqama.
NOTIFY_IQAMA = True

APP_NAME = "Prayer Times"
SOUND_EVENT = "message-new-instant"
SOUND_FILE = "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
ICON = "appointment-soon"

ADHAN = "adhan"
IQAMA = "iqama"

# An event older than this is not announced. Without it, resuming from suspend
# at midnight would fire every prayer the machine slept through at once.
DEFAULT_GRACE = timedelta(minutes=2)


def events_for(schedule: dict) -> list:
    """[(when, kind, prayer_name)] for today, chronological.

    Sunrise is excluded: it closes the Fajr window but is not a prayer and has
    no iqama.
    """
    events = []
    for name in prayer.IQAMA_PRAYERS:
        events.append((schedule["times"][name], ADHAN, name))
        if NOTIFY_IQAMA:
            events.append((schedule["iqamas"][name], IQAMA, name))
    events.sort(key=lambda item: item[0])
    return events


def due_events(events: list, last_check, now, grace=DEFAULT_GRACE) -> list:
    """Events that fell in (last_check, now] and are not staler than grace."""
    due = []
    for when, kind, name in events:
        if last_check < when <= now and (now - when) <= grace:
            due.append((when, kind, name))
    return due


def compose(kind: str, name: str, schedule: dict):
    """Return (summary, body) for a notification."""
    english = prayer.DISPLAY_NAMES[name]
    arabic = prayer.ARABIC_NAMES[name]
    adhan_at = schedule["times"][name]
    iqama_at = schedule["iqamas"][name]

    if kind == ADHAN:
        summary = f"{english}  {arabic}"
        offset = prayer.IQAMA_OFFSETS[name]
        body = (f"Adhan {adhan_at:%H:%M}"
                f"  ·  Iqama {iqama_at:%H:%M} (+{offset} min)")
    else:
        summary = f"{english} — Iqama  {arabic}"
        body = f"Iqama now, {iqama_at:%H:%M}"
    return summary, body


def _spawn(argv: list) -> None:
    """Fire and forget. Never blocks the caller, never raises."""
    if not shutil.which(argv[0]):
        return
    try:
        subprocess.Popen(argv,
                         stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except OSError:
        pass


def play_sound() -> None:
    """canberra by event id, falling back to the raw file via paplay."""
    if shutil.which("canberra-gtk-play"):
        _spawn(["canberra-gtk-play", "-i", SOUND_EVENT])
    else:
        _spawn(["paplay", SOUND_FILE])


def notify(summary: str, body: str, timeout_ms: int = 12000) -> None:
    _spawn(["notify-send", "-a", APP_NAME, "-i", ICON,
            "-u", "normal", "-t", str(timeout_ms), summary, body])


def announce(kind: str, name: str, schedule: dict) -> None:
    summary, body = compose(kind, name, schedule)
    notify(summary, body, timeout_ms=15000 if kind == IQAMA else 12000)
    play_sound()
