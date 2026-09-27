import json
import os
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import hudjson  # noqa: E402
import timetable  # noqa: E402

TZ = ZoneInfo("Asia/Jerusalem")
DAY = date(2026, 9, 26)


def _at(hhmm: str) -> datetime:
    h, m = map(int, hhmm.split(":"))
    return datetime(DAY.year, DAY.month, DAY.day, h, m, tzinfo=TZ)


TIMES = {"fajr": _at("05:08"), "sunrise": _at("06:30"), "dhuhr": _at("12:30"),
         "asr": _at("15:57"), "maghrib": _at("18:36"), "isha": _at("19:52")}
IQAMAS = {"fajr": _at("05:28"), "dhuhr": _at("12:45"), "asr": _at("16:12"),
          "maghrib": _at("18:43"), "isha": _at("20:07")}


def _schedule(now: str, **over) -> dict:
    s = {
        "now": _at(now), "date": DAY, "times": TIMES, "iqamas": IQAMAS,
        "next_prayer": "dhuhr", "next_time": TIMES["dhuhr"], "next_iqama": IQAMAS["dhuhr"],
        "next_is_tomorrow": False, "current_prayer": "fajr",
        "until_next": TIMES["dhuhr"] - _at(now),
        "in_iqama_window": False, "until_iqama": timedelta(0),
        "source": timetable.SOURCE_OFFICIAL, "hijri": "15 Rabīʿ al-thānī 1448",
    }
    s.update(over)
    return s


def _states(p: dict) -> dict:
    return {r["name"]: r["state"] for r in p["rows"]}


def test_next_prayer_hero_and_row_states():
    p = hudjson.payload(_schedule("10:42"))
    assert p["hero"] == {"urgent": False, "caption": "NEXT", "arabic": "الظهر",
                         "big": "1h 48m", "detail": "Dhuhr 12:30  →  iqama 12:45"}
    assert _states(p) == {"Fajr": "past", "Sunrise": "sunrise", "Dhuhr": "live",
                          "Asr": "normal", "Maghrib": "normal", "Isha": "normal"}
    assert p["clock"] == "10:42"
    assert p["dates"].endswith("15 Rabīʿ al-thānī 1448")
    assert p["fallback"] is False


def test_iqama_window_is_urgent_and_marks_current_live():
    p = hudjson.payload(_schedule("12:36", in_iqama_window=True, current_prayer="dhuhr",
                                  until_iqama=IQAMAS["dhuhr"] - _at("12:36"),
                                  next_prayer="asr", next_time=TIMES["asr"],
                                  next_iqama=IQAMAS["asr"]))
    assert p["hero"]["urgent"] is True
    assert p["hero"]["caption"] == "IQAMA IN"
    assert p["hero"]["big"] == "9m"
    assert _states(p)["Dhuhr"] == "live"
    assert _states(p)["Asr"] == "normal"


def test_tomorrow_has_no_live_row():
    p = hudjson.payload(_schedule("22:00", next_prayer="fajr", next_is_tomorrow=True,
                                  current_prayer="isha"))
    assert p["hero"]["caption"] == "NEXT (tomorrow)"
    assert "live" not in _states(p).values()


def test_fallback_flag_when_not_official():
    assert hudjson.payload(_schedule("10:42", source="computed"))["fallback"] is True


def test_write_atomic_roundtrip_and_no_temp_left(tmp_path):
    target = tmp_path / "hud.json"
    hudjson.write_atomic(str(target), {"a": "الظهر"})
    assert json.loads(target.read_text(encoding="utf-8")) == {"a": "الظهر"}
    assert os.listdir(tmp_path) == ["hud.json"]
