"""Validation against api.aladhan.com method=23 (Jordan / Awqaf), school=0.

Reference values were fetched once and frozen here, deliberately covering both
solstices, an equinox, and either side of the 2026 DST transition — the places
where a solar-geometry bug actually shows up. A same-day-only test would pass
with a badly broken implementation.
"""

import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import prayer

TZ = ZoneInfo("Asia/Jerusalem")

# date -> {prayer: "HH:MM"} from the Jordan Ministry of Awqaf method.
REFERENCE = {
    date(2026, 8, 29): {"fajr": "04:48", "sunrise": "06:13", "dhuhr": "12:40",
                        "asr": "16:17", "maghrib": "19:12", "isha": "20:32"},
    date(2026, 12, 21): {"fajr": "05:08", "sunrise": "06:35", "dhuhr": "11:37",
                         "asr": "14:21", "maghrib": "16:44", "isha": "18:07"},
    date(2026, 6, 21): {"fajr": "03:54", "sunrise": "05:34", "dhuhr": "12:41",
                        "asr": "16:21", "maghrib": "19:53", "isha": "21:28"},
    date(2026, 3, 20): {"fajr": "04:22", "sunrise": "05:43", "dhuhr": "11:47",
                        "asr": "15:13", "maghrib": "17:55", "isha": "19:12"},
    date(2026, 10, 24): {"fajr": "05:27", "sunrise": "06:49", "dhuhr": "12:23",
                         "asr": "15:33", "maghrib": "18:02", "isha": "19:19"},
    date(2026, 10, 26): {"fajr": "04:28", "sunrise": "05:50", "dhuhr": "11:23",
                         "asr": "14:32", "maghrib": "17:00", "isha": "18:17"},
}

TOLERANCE_MIN = 1


def _diff_minutes(got: datetime, expected_hhmm: str, day: date) -> int:
    hh, mm = (int(x) for x in expected_hhmm.split(":"))
    want = datetime(day.year, day.month, day.day, hh, mm, tzinfo=TZ)
    return abs(int((got - want).total_seconds() // 60))


def test_matches_reference_within_one_minute():
    failures = []
    for day, expected in REFERENCE.items():
        times = prayer.prayer_times(day)
        for name, hhmm in expected.items():
            delta = _diff_minutes(times[name], hhmm, day)
            if delta > TOLERANCE_MIN:
                failures.append(
                    f"{day} {name}: got {times[name]:%H:%M} want {hhmm} ({delta}m off)")
    assert not failures, "\n".join(failures)


def test_dst_transition_shifts_times_by_an_hour():
    before = prayer.prayer_times(date(2026, 10, 24))
    after = prayer.prayer_times(date(2026, 10, 26))
    # Dhuhr moves back roughly an hour across the DST end.
    shift = (before["dhuhr"].hour * 60 + before["dhuhr"].minute) - \
            (after["dhuhr"].hour * 60 + after["dhuhr"].minute)
    assert 55 <= shift <= 65, f"expected ~60min DST shift, got {shift}"


def test_maghrib_offset_from_sunset_is_applied():
    """The Jordan method puts Maghrib 5 min after sunset, not at sunset.

    Asserted against the reference rather than a hardcoded string: this module
    is the offline fallback and is documented as accurate to +/-1 minute
    against the published table, so an exact-equality assertion here would be
    asserting something the implementation does not promise.
    """
    day = date(2026, 8, 29)
    times = prayer.prayer_times(day)
    assert _diff_minutes(times["maghrib"], "19:12", day) <= TOLERANCE_MIN
    # Without the +5 offset it would land at ~19:07, which is 5 min out.
    assert _diff_minutes(times["maghrib"], "19:07", day) > TOLERANCE_MIN


def test_times_are_ordered_through_the_day():
    for day in REFERENCE:
        times = prayer.prayer_times(day)
        ordered = [times[n] for n in prayer.PRAYERS]
        assert ordered == sorted(ordered), f"{day}: prayer times out of order"


def test_iqama_offsets_applied():
    times = prayer.prayer_times(date(2026, 8, 29))
    iqamas = prayer.iqama_times(times)
    assert iqamas["fajr"] - times["fajr"] == timedelta(minutes=20)
    assert iqamas["dhuhr"] - times["dhuhr"] == timedelta(minutes=15)
    assert iqamas["asr"] - times["asr"] == timedelta(minutes=15)
    assert iqamas["maghrib"] - times["maghrib"] == timedelta(minutes=7)
    assert iqamas["isha"] - times["isha"] == timedelta(minutes=7)


def test_sunrise_has_no_iqama():
    iqamas = prayer.iqama_times(prayer.prayer_times(date(2026, 8, 29)))
    assert "sunrise" not in iqamas


def test_next_prayer_midday():
    current = datetime(2026, 8, 29, 13, 0, tzinfo=TZ)  # after dhuhr 12:40
    s = prayer.schedule(current)
    assert s["next_prayer"] == "asr"
    assert s["current_prayer"] == "dhuhr"
    assert not s["next_is_tomorrow"]


def test_next_prayer_before_fajr():
    current = datetime(2026, 8, 29, 3, 0, tzinfo=TZ)
    s = prayer.schedule(current)
    assert s["next_prayer"] == "fajr"
    assert s["current_prayer"] is None


def test_after_isha_rolls_to_tomorrow_fajr():
    current = datetime(2026, 8, 29, 23, 30, tzinfo=TZ)  # isha was 20:32
    s = prayer.schedule(current)
    assert s["next_prayer"] == "fajr"
    assert s["next_is_tomorrow"] is True
    assert s["next_time"].date() == date(2026, 8, 30)
    assert s["until_next"].total_seconds() > 0


def test_countdown_never_negative():
    assert prayer.format_countdown(timedelta(seconds=-500)) == "now"
    assert prayer.format_countdown(timedelta(0)) == "now"


def test_countdown_formatting():
    assert prayer.format_countdown(timedelta(minutes=12)) == "12m"
    assert prayer.format_countdown(timedelta(hours=1, minutes=24)) == "1h 24m"
    assert prayer.format_countdown(timedelta(hours=2)) == "2h 00m"
