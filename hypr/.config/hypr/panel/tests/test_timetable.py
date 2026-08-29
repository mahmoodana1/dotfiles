"""Cache-layer tests. These must never touch the network.

fetch_month is monkeypatched throughout; CACHE_DIR is redirected to tmp_path so
a test run cannot read or clobber the real cache.
"""

import json
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import prayer
import timetable

TZ = ZoneInfo("Asia/Jerusalem")

SAMPLE_PAYLOAD = {
    "data": [
        {
            "timings": {
                "Fajr": "04:48 (IDT)", "Sunrise": "06:13 (IDT)",
                "Dhuhr": "12:40 (IDT)", "Asr": "16:17 (IDT)",
                "Maghrib": "19:12 (IDT)", "Isha": "20:32 (IDT)",
            },
            "date": {
                "gregorian": {"date": "29-08-2026"},
                "hijri": {"day": "16", "month": {"en": "Rabi al-awwal"},
                          "year": "1448"},
            },
        },
        {   # malformed: missing timings, must be skipped not fatal
            "date": {"gregorian": {"date": "30-08-2026"}},
        },
    ]
}


@pytest.fixture(autouse=True)
def isolate_cache(tmp_path, monkeypatch):
    monkeypatch.setattr(timetable, "CACHE_DIR", str(tmp_path))
    monkeypatch.setattr(timetable, "fetch_month",
                        lambda y, m: pytest.fail("network access attempted"))


def test_parse_calendar_extracts_day():
    days = timetable.parse_calendar(SAMPLE_PAYLOAD)
    assert "2026-08-29" in days
    assert days["2026-08-29"]["fajr"] == "04:48"
    assert days["2026-08-29"]["isha"] == "20:32"
    assert "Rabi al-awwal" in days["2026-08-29"]["hijri"]


def test_parse_calendar_skips_malformed_day():
    days = timetable.parse_calendar(SAMPLE_PAYLOAD)
    assert "2026-08-30" not in days
    assert len(days) == 1


def test_parse_calendar_empty_payload():
    assert timetable.parse_calendar({}) == {}


def test_save_and_load_round_trip():
    days = timetable.parse_calendar(SAMPLE_PAYLOAD)
    timetable.save_month(2026, 8, days)
    assert timetable.load_month(2026, 8) == days


def test_load_month_absent_returns_empty():
    assert timetable.load_month(2030, 1) == {}


def test_load_month_rejects_stale_location(monkeypatch):
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    monkeypatch.setattr(prayer, "LATITUDE", 40.0)     # user moved
    assert timetable.load_month(2026, 8) == {}


def test_load_month_rejects_corrupt_file():
    Path(timetable.cache_path(2026, 8)).write_text("{ not json", encoding="utf-8")
    assert timetable.load_month(2026, 8) == {}


def test_times_for_uses_cache_when_present():
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    times, source, hijri = timetable.times_for(date(2026, 8, 29))
    assert source == timetable.SOURCE_OFFICIAL
    assert f"{times['fajr']:%H:%M}" == "04:48"
    assert f"{times['maghrib']:%H:%M}" == "19:12"
    assert "Rabi al-awwal" in hijri


def test_times_for_falls_back_to_computed():
    times, source, hijri = timetable.times_for(date(2026, 8, 29))
    assert source == timetable.SOURCE_COMPUTED
    assert hijri is None
    # Fallback still lands within the documented tolerance.
    assert times["fajr"].hour == 4


def test_schedule_reports_source():
    current = datetime(2026, 8, 29, 13, 0, tzinfo=TZ)
    s = timetable.schedule(current)
    assert s["source"] in (timetable.SOURCE_OFFICIAL, timetable.SOURCE_COMPUTED)
    assert s["next_prayer"] == "asr"


def test_schedule_uses_official_times_when_cached():
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    current = datetime(2026, 8, 29, 13, 0, tzinfo=TZ)
    s = timetable.schedule(current)
    assert s["source"] == timetable.SOURCE_OFFICIAL
    assert f"{s['next_time']:%H:%M}" == "16:17"          # asr
    assert f"{s['next_iqama']:%H:%M}" == "16:32"         # asr + 15
    assert s["hijri"] is not None


def test_iqama_window_detected_between_adhan_and_iqama():
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    # Dhuhr 12:40, iqama 12:55. 12:47 is inside that window.
    s = timetable.schedule(datetime(2026, 8, 29, 12, 47, tzinfo=TZ))
    assert s["in_iqama_window"] is True
    assert s["current_prayer"] == "dhuhr"
    assert prayer.format_countdown(s["until_iqama"]) == "8m"


def test_iqama_window_closed_after_iqama():
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    s = timetable.schedule(datetime(2026, 8, 29, 13, 10, tzinfo=TZ))
    assert s["in_iqama_window"] is False
    assert s["until_iqama"] is None


def test_iqama_window_false_before_first_prayer():
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    s = timetable.schedule(datetime(2026, 8, 29, 3, 0, tzinfo=TZ))
    assert s["in_iqama_window"] is False
    assert s["current_prayer"] is None


def test_refresh_skips_fetch_when_cached(monkeypatch):
    timetable.save_month(2026, 8, timetable.parse_calendar(SAMPLE_PAYLOAD))
    # fetch_month would fail the test if called; a cached month must not fetch.
    assert timetable.refresh(date(2026, 8, 10)) is False


def test_refresh_writes_when_fetch_succeeds(monkeypatch):
    days = timetable.parse_calendar(SAMPLE_PAYLOAD)
    monkeypatch.setattr(timetable, "fetch_month", lambda y, m: days)
    assert timetable.refresh(date(2026, 8, 10)) is True
    assert timetable.load_month(2026, 8) == days


def test_refresh_survives_fetch_failure(monkeypatch):
    monkeypatch.setattr(timetable, "fetch_month", lambda y, m: {})
    assert timetable.refresh(date(2026, 8, 10)) is False
    assert timetable.load_month(2026, 8) == {}


def test_refresh_prefetches_next_month_near_boundary(monkeypatch):
    seen = []

    def fake_fetch(year, month):
        seen.append((year, month))
        return timetable.parse_calendar(SAMPLE_PAYLOAD)

    monkeypatch.setattr(timetable, "fetch_month", fake_fetch)
    timetable.refresh(date(2026, 8, 29))     # within 5 days of month end
    assert (2026, 8) in seen and (2026, 9) in seen


def test_refresh_does_not_prefetch_mid_month(monkeypatch):
    seen = []

    def fake_fetch(year, month):
        seen.append((year, month))
        return timetable.parse_calendar(SAMPLE_PAYLOAD)

    monkeypatch.setattr(timetable, "fetch_month", fake_fetch)
    timetable.refresh(date(2026, 8, 10))
    assert seen == [(2026, 8)]
