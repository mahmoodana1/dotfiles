"""Prayer-time calculation for Wadi al-Joz, Jerusalem. Pure logic — no GTK.

Solar-geometry implementation of the standard method (PrayTimes.org algorithm),
configured for the Ministry of Awqaf, Islamic Affairs and Holy Places (Jordan),
which administers the Jerusalem Islamic Waqf and Al-Aqsa.

  Fajr    18 degrees below horizon
  Isha    18 degrees below horizon
  Maghrib sunset + 5 minutes   <- specific to the Jordan method, not sunset
  Asr     standard shadow ratio 1 (Shafi'i / Maliki / Hanbali)

Verified against api.aladhan.com method=23 school=0 across solstices, an
equinox, and both sides of the DST transition. See tests/test_prayer.py.
"""

import math
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

# Wadi al-Joz, East Jerusalem.
LATITUDE = 31.7897
LONGITUDE = 35.2367
TIMEZONE = "Asia/Jerusalem"

FAJR_ANGLE = 18.0
ISHA_ANGLE = 18.0
MAGHRIB_OFFSET_MIN = 5     # Jordan method: Maghrib is 5 min after sunset
ASR_SHADOW_FACTOR = 1      # standard; Hanafi would be 2
SUNRISE_ANGLE = 0.833      # refraction + solar disc radius

PRAYERS = ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

# Minutes between the adhan and the iqama, per the user's mosque.
IQAMA_OFFSETS = {
    "fajr": 20,
    "dhuhr": 15,
    "asr": 15,
    "maghrib": 7,
    "isha": 7,
}

# Sunrise is not a prayer; it marks the end of Fajr's window.
IQAMA_PRAYERS = ("fajr", "dhuhr", "asr", "maghrib", "isha")

DISPLAY_NAMES = {
    "fajr": "Fajr",
    "sunrise": "Sunrise",
    "dhuhr": "Dhuhr",
    "asr": "Asr",
    "maghrib": "Maghrib",
    "isha": "Isha",
}

ARABIC_NAMES = {
    "fajr": "الفجر",
    "sunrise": "الشروق",
    "dhuhr": "الظهر",
    "asr": "العصر",
    "maghrib": "المغرب",
    "isha": "العشاء",
}


def _fixangle(a: float) -> float:
    return a - 360.0 * math.floor(a / 360.0)


def _fixhour(a: float) -> float:
    return a - 24.0 * math.floor(a / 24.0)


def _julian(d: date) -> float:
    year, month, day = d.year, d.month, d.day
    if month <= 2:
        year -= 1
        month += 12
    a = math.floor(year / 100.0)
    b = 2 - a + math.floor(a / 4.0)
    return (math.floor(365.25 * (year + 4716))
            + math.floor(30.6001 * (month + 1))
            + day + b - 1524.5)


def _sun_position(jd: float):
    """Return (declination, equation_of_time) in degrees and hours."""
    d = jd - 2451545.0
    g = _fixangle(357.529 + 0.98560028 * d)
    q = _fixangle(280.459 + 0.98564736 * d)
    lam = _fixangle(q + 1.915 * math.sin(math.radians(g))
                    + 0.020 * math.sin(math.radians(2 * g)))
    e = 23.439 - 0.00000036 * d

    decl = math.degrees(math.asin(
        math.sin(math.radians(e)) * math.sin(math.radians(lam))))
    ra = math.degrees(math.atan2(
        math.cos(math.radians(e)) * math.sin(math.radians(lam)),
        math.cos(math.radians(lam)))) / 15.0
    eqt = q / 15.0 - _fixhour(ra)
    return decl, eqt


def _sun_angle_time(angle: float, decl: float, noon: float,
                    latitude: float, ccw: bool) -> float:
    """Hours (local solar) at which the sun sits `angle` degrees below horizon."""
    lat_r = math.radians(latitude)
    decl_r = math.radians(decl)
    numerator = -math.sin(math.radians(angle)) - math.sin(decl_r) * math.sin(lat_r)
    denominator = math.cos(decl_r) * math.cos(lat_r)
    ratio = numerator / denominator
    # Clamp: guards against no-sunrise/no-sunset at extreme latitudes. Jerusalem
    # never triggers this, but an out-of-domain acos would crash the daemon.
    ratio = max(-1.0, min(1.0, ratio))
    t = math.degrees(math.acos(ratio)) / 15.0
    return noon - t if ccw else noon + t


def _asr_time(factor: int, decl: float, noon: float, latitude: float) -> float:
    angle = -math.degrees(math.atan(
        1.0 / (factor + math.tan(math.radians(abs(latitude - decl))))))
    return _sun_angle_time(angle, decl, noon, latitude, ccw=False)


def _to_datetime(day: date, hours: float, tz: ZoneInfo) -> datetime:
    """Convert a float hour into a wall-clock datetime, rounded to the minute."""
    total = int(round(hours * 60.0))
    return datetime(day.year, day.month, day.day, tzinfo=tz) + timedelta(minutes=total)


def prayer_times(day: date,
                 latitude: float = LATITUDE,
                 longitude: float = LONGITUDE,
                 timezone: str = TIMEZONE) -> dict:
    """Return {name: aware datetime} for the six daily marks."""
    tz = ZoneInfo(timezone)
    # UTC offset for this specific date, so DST transitions are handled.
    offset = datetime(day.year, day.month, day.day, 12, tzinfo=tz).utcoffset()
    tz_hours = offset.total_seconds() / 3600.0

    jd = _julian(day) - longitude / (15.0 * 24.0)
    decl, eqt = _sun_position(jd)

    noon = _fixhour(12.0 - eqt)

    raw = {
        "fajr": _sun_angle_time(FAJR_ANGLE, decl, noon, latitude, ccw=True),
        "sunrise": _sun_angle_time(SUNRISE_ANGLE, decl, noon, latitude, ccw=True),
        "dhuhr": noon,
        "asr": _asr_time(ASR_SHADOW_FACTOR, decl, noon, latitude),
        "sunset": _sun_angle_time(SUNRISE_ANGLE, decl, noon, latitude, ccw=False),
        "isha": _sun_angle_time(ISHA_ANGLE, decl, noon, latitude, ccw=False),
    }

    # Shift from solar to local wall-clock time.
    shift = tz_hours - longitude / 15.0
    times = {k: v + shift for k, v in raw.items()}
    times["maghrib"] = times["sunset"] + MAGHRIB_OFFSET_MIN / 60.0

    return {name: _to_datetime(day, times[name], tz) for name in PRAYERS}


def iqama_times(times: dict) -> dict:
    """Map each prayer to its iqama datetime."""
    return {name: times[name] + timedelta(minutes=IQAMA_OFFSETS[name])
            for name in IQAMA_PRAYERS}


def now(timezone: str = TIMEZONE) -> datetime:
    return datetime.now(ZoneInfo(timezone))


def schedule(current: datetime = None, timezone: str = TIMEZONE) -> dict:
    """Everything the panel needs: today's times, iqamas, and what's next.

    `next_prayer` is the upcoming prayer (never sunrise). When the last isha
    iqama of the day has passed it rolls to tomorrow's fajr, so the panel is
    never blank after midnight.
    """
    tz = ZoneInfo(timezone)
    current = current or datetime.now(tz)
    today = current.date()

    times = prayer_times(today, timezone=timezone)
    iqamas = iqama_times(times)

    upcoming = None
    for name in IQAMA_PRAYERS:
        if times[name] > current:
            upcoming = name
            break

    if upcoming is None:
        tomorrow = today + timedelta(days=1)
        t_times = prayer_times(tomorrow, timezone=timezone)
        next_time = t_times["fajr"]
        next_iqama = next_time + timedelta(minutes=IQAMA_OFFSETS["fajr"])
        upcoming = "fajr"
        tomorrow_flag = True
    else:
        next_time = times[upcoming]
        next_iqama = iqamas[upcoming]
        tomorrow_flag = False

    # The prayer whose window we are currently in.
    current_prayer = None
    for name in reversed(IQAMA_PRAYERS):
        if times[name] <= current:
            current_prayer = name
            break

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
    }


def format_countdown(delta: timedelta) -> str:
    """'1h 24m' / '12m' / 'now'. Never negative."""
    total = int(delta.total_seconds())
    if total <= 0:
        return "now"
    hours, remainder = divmod(total, 3600)
    minutes = remainder // 60
    if hours:
        return f"{hours}h {minutes:02d}m"
    return f"{minutes}m"
