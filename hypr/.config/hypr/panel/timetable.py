"""Official timetable cache with offline fallback. Pure logic — no GTK.

Prefers the published Jordan Ministry of Awqaf timetable (api.aladhan.com,
method 23), cached a month at a time so normal operation makes roughly one
network request per month. Falls back to the local calculation in prayer.py
when no cache is available, and always reports which source is in play so the
panel can say so rather than quietly showing different numbers.

Reads never touch the network. Fetching happens only in refresh(), which the
daemon calls on a background thread.
"""

import json
import os
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import prayer

API = "https://api.aladhan.com/v1/calendar/{year}/{month}"
METHOD = 23   # Ministry of Awqaf, Jordan — administers the Jerusalem Waqf
SCHOOL = 0    # standard Asr (Shafi'i/Maliki/Hanbali)
TIMEOUT = 10

SOURCE_OFFICIAL = "official"
SOURCE_COMPUTED = "computed"

CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "hypr-panel")

_API_KEYS = {
    "fajr": "Fajr", "sunrise": "Sunrise", "dhuhr": "Dhuhr",
    "asr": "Asr", "maghrib": "Maghrib", "isha": "Isha",
}


def cache_path(year: int, month: int) -> str:
    return os.path.join(CACHE_DIR, f"timings-{year:04d}-{month:02d}.json")


def _strip_zone(value: str) -> str:
    """'19:12 (IDT)' -> '19:12'."""
    return value.split()[0].strip()


def parse_calendar(payload: dict) -> dict:
    """Convert an aladhan calendar response into {'YYYY-MM-DD': {...}}."""
    days = {}
    for entry in payload.get("data", []):
        try:
            gregorian = entry["date"]["gregorian"]["date"]      # DD-MM-YYYY
            day, month, year = gregorian.split("-")
            key = f"{year}-{month}-{day}"
            timings = entry["timings"]
            record = {name: _strip_zone(timings[api_key])
                      for name, api_key in _API_KEYS.items()}
            hijri = entry["date"]["hijri"]
            record["hijri"] = (f"{int(hijri['day'])} {hijri['month']['en']} "
                               f"{hijri['year']}")
            days[key] = record
        except (KeyError, ValueError, IndexError):
            continue    # skip malformed day rather than losing the whole month
    return days


def load_month(year: int, month: int) -> dict:
    """Read a cached month. Returns {} when absent, unreadable, or stale-config."""
    try:
        with open(cache_path(year, month), encoding="utf-8") as handle:
            blob = json.load(handle)
    except (OSError, ValueError):
        return {}
    # A change of location or method invalidates the cache.
    if (blob.get("method") != METHOD or blob.get("school") != SCHOOL
            or abs(blob.get("latitude", 0) - prayer.LATITUDE) > 1e-6
            or abs(blob.get("longitude", 0) - prayer.LONGITUDE) > 1e-6):
        return {}
    days = blob.get("days")
    return days if isinstance(days, dict) else {}


def save_month(year: int, month: int, days: dict) -> None:
    os.makedirs(CACHE_DIR, exist_ok=True)
    blob = {
        "fetched": datetime.now(ZoneInfo(prayer.TIMEZONE)).isoformat(),
        "method": METHOD,
        "school": SCHOOL,
        "latitude": prayer.LATITUDE,
        "longitude": prayer.LONGITUDE,
        "days": days,
    }
    target = cache_path(year, month)
    tmp = target + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(blob, handle, ensure_ascii=False)
    os.replace(tmp, target)     # atomic: a torn write can't corrupt the cache


def fetch_month(year: int, month: int) -> dict:
    """Network. Returns parsed days, or {} on any failure."""
    url = (API.format(year=year, month=month)
           + f"?latitude={prayer.LATITUDE}&longitude={prayer.LONGITUDE}"
           + f"&method={METHOD}&school={SCHOOL}")
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, ValueError, TimeoutError):
        return {}
    return parse_calendar(payload)


def refresh(today: date = None) -> bool:
    """Ensure this month is cached, and next month too near the boundary.

    Network-bound; call from a background thread. Returns True if anything was
    written. Never raises — a failed refresh just leaves the fallback in place.
    """
    today = today or datetime.now(ZoneInfo(prayer.TIMEZONE)).date()
    wrote = False

    wanted = [(today.year, today.month)]
    # Within 5 days of month end, make sure the next month is ready too.
    following = today + timedelta(days=5)
    if (following.year, following.month) != (today.year, today.month):
        wanted.append((following.year, following.month))

    for year, month in wanted:
        if load_month(year, month):
            continue
        days = fetch_month(year, month)
        if days:
            try:
                save_month(year, month, days)
                wrote = True
            except OSError:
                pass
    return wrote


def times_for(day: date):
    """Return (times, source, hijri). Never touches the network.

    times: {prayer_name: aware datetime}
    source: 'official' | 'computed'
    hijri: str | None
    """
    cached = load_month(day.year, day.month).get(day.isoformat())
    if cached:
        tz = ZoneInfo(prayer.TIMEZONE)
        try:
            times = {}
            for name in prayer.PRAYERS:
                hour, minute = (int(x) for x in cached[name].split(":"))
                times[name] = datetime(day.year, day.month, day.day,
                                       hour, minute, tzinfo=tz)
            return times, SOURCE_OFFICIAL, cached.get("hijri")
        except (KeyError, ValueError):
            pass    # fall through to computed
    return prayer.prayer_times(day), SOURCE_COMPUTED, None


def schedule(current: datetime = None) -> dict:
    """prayer.schedule() backed by the official timetable when available."""
    tz = ZoneInfo(prayer.TIMEZONE)
    if current is None:
        # Debug aid: HUDPANEL_FAKE_NOW=2026-08-29T12:47 previews the panel at an
        # arbitrary moment, so the highlight and iqama-window states can be
        # checked without waiting for the actual prayer time.
        override = os.environ.get("HUDPANEL_FAKE_NOW")
        if override:
            try:
                current = datetime.fromisoformat(override).replace(tzinfo=tz)
            except ValueError:
                current = datetime.now(tz)
        else:
            current = datetime.now(tz)
    today = current.date()

    times, source, hijri = times_for(today)
    iqamas = prayer.iqama_times(times)

    upcoming = None
    for name in prayer.IQAMA_PRAYERS:
        if times[name] > current:
            upcoming = name
            break

    if upcoming is None:
        tomorrow = today + timedelta(days=1)
        t_times, _, _ = times_for(tomorrow)
        upcoming = "fajr"
        next_time = t_times["fajr"]
        next_iqama = next_time + timedelta(
            minutes=prayer.IQAMA_OFFSETS["fajr"])
        tomorrow_flag = True
    else:
        next_time = times[upcoming]
        next_iqama = iqamas[upcoming]
        tomorrow_flag = False

    current_prayer = None
    for name in reversed(prayer.IQAMA_PRAYERS):
        if times[name] <= current:
            current_prayer = name
            break

    # Between the adhan and the iqama of the prayer just called. This is the
    # most time-critical state there is, so the panel leads with it instead of
    # the next prayer hours away.
    in_iqama_window = False
    until_iqama = None
    if current_prayer is not None and current < iqamas[current_prayer]:
        in_iqama_window = True
        until_iqama = iqamas[current_prayer] - current

    return {
        "now": current,
        "date": today,
        "times": times,
        "iqamas": iqamas,
        "next_prayer": upcoming,
        "next_time": next_time,
        "next_iqama": next_iqama,
        "next_is_tomorrow": tomorrow_flag,
        "current_prayer": current_prayer,
        "until_next": next_time - current,
        "in_iqama_window": in_iqama_window,
        "until_iqama": until_iqama,
        "source": source,
        "hijri": hijri,
    }
