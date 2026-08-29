"""Alert scheduling tests. Nothing here may spawn a real notification."""

import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import alerts
import prayer

TZ = ZoneInfo("Asia/Jerusalem")
DAY = date(2026, 8, 29)


@pytest.fixture
def schedule():
    times = prayer.prayer_times(DAY)
    return {
        "times": times,
        "iqamas": prayer.iqama_times(times),
        "now": datetime(DAY.year, DAY.month, DAY.day, 12, 0, tzinfo=TZ),
    }


@pytest.fixture(autouse=True)
def no_spawning(monkeypatch):
    monkeypatch.setattr(alerts, "_spawn",
                        lambda argv: pytest.fail(f"spawned {argv!r}"))


def at(hour, minute, second=0):
    return datetime(DAY.year, DAY.month, DAY.day, hour, minute, second, tzinfo=TZ)


def test_events_cover_adhan_and_iqama(schedule):
    events = alerts.events_for(schedule)
    assert len(events) == 10          # 5 prayers x (adhan + iqama)
    kinds = {kind for _, kind, _ in events}
    assert kinds == {alerts.ADHAN, alerts.IQAMA}


def test_events_exclude_sunrise(schedule):
    names = {name for _, _, name in alerts.events_for(schedule)}
    assert "sunrise" not in names


def test_events_are_chronological(schedule):
    events = alerts.events_for(schedule)
    assert [e[0] for e in events] == sorted(e[0] for e in events)


def test_iqama_can_be_disabled(monkeypatch, schedule):
    monkeypatch.setattr(alerts, "NOTIFY_IQAMA", False)
    events = alerts.events_for(schedule)
    assert len(events) == 5
    assert {kind for _, kind, _ in events} == {alerts.ADHAN}


def test_due_fires_event_crossed_since_last_check(schedule):
    events = alerts.events_for(schedule)
    dhuhr = schedule["times"]["dhuhr"]
    due = alerts.due_events(events, dhuhr - timedelta(seconds=10),
                            dhuhr + timedelta(seconds=5))
    assert [(k, n) for _, k, n in due] == [(alerts.ADHAN, "dhuhr")]


def test_due_is_empty_when_nothing_crossed(schedule):
    events = alerts.events_for(schedule)
    due = alerts.due_events(events, at(13, 0), at(13, 0, 10))
    assert due == []


def test_due_does_not_refire_same_event(schedule):
    """The window is half-open, so an event exactly at last_check is spent."""
    events = alerts.events_for(schedule)
    dhuhr = schedule["times"]["dhuhr"]
    due = alerts.due_events(events, dhuhr, dhuhr + timedelta(seconds=30))
    assert due == []


def test_stale_events_suppressed_after_long_sleep(schedule):
    """Resuming from suspend must not dump every missed prayer at once."""
    events = alerts.events_for(schedule)
    due = alerts.due_events(events, at(3, 0), at(23, 0))
    assert due == [], "a full day of missed events should be suppressed"


def test_event_just_inside_grace_still_fires(schedule):
    events = alerts.events_for(schedule)
    dhuhr = schedule["times"]["dhuhr"]
    due = alerts.due_events(events, dhuhr - timedelta(seconds=1),
                            dhuhr + timedelta(seconds=90))
    assert [(k, n) for _, k, n in due] == [(alerts.ADHAN, "dhuhr")]


def test_event_just_outside_grace_suppressed(schedule):
    events = alerts.events_for(schedule)
    dhuhr = schedule["times"]["dhuhr"]
    due = alerts.due_events(events, dhuhr - timedelta(seconds=1),
                            dhuhr + timedelta(seconds=150))
    assert due == []


def test_adhan_and_iqama_both_fire_in_one_window(schedule):
    """A tick spanning both must report both, in order."""
    events = alerts.events_for(schedule)
    maghrib = schedule["times"]["maghrib"]          # iqama is +7 min
    due = alerts.due_events(events,
                            maghrib - timedelta(seconds=5),
                            maghrib + timedelta(minutes=7, seconds=5),
                            grace=timedelta(minutes=10))
    assert [(k, n) for _, k, n in due] == [
        (alerts.ADHAN, "maghrib"), (alerts.IQAMA, "maghrib")]


def test_compose_adhan_mentions_both_times(schedule):
    summary, body = alerts.compose(alerts.ADHAN, "dhuhr", schedule)
    assert "Dhuhr" in summary
    assert prayer.ARABIC_NAMES["dhuhr"] in summary
    assert f"{schedule['times']['dhuhr']:%H:%M}" in body
    assert f"{schedule['iqamas']['dhuhr']:%H:%M}" in body
    assert "+15 min" in body


def test_compose_iqama_is_distinct_from_adhan(schedule):
    adhan_summary, _ = alerts.compose(alerts.ADHAN, "maghrib", schedule)
    iqama_summary, iqama_body = alerts.compose(alerts.IQAMA, "maghrib", schedule)
    assert adhan_summary != iqama_summary
    assert "Iqama" in iqama_summary
    assert f"{schedule['iqamas']['maghrib']:%H:%M}" in iqama_body


def test_play_sound_prefers_canberra(monkeypatch):
    calls = []
    monkeypatch.setattr(alerts, "_spawn", calls.append)
    monkeypatch.setattr(alerts.shutil, "which",
                        lambda name: "/usr/bin/canberra-gtk-play"
                        if name == "canberra-gtk-play" else None)
    alerts.play_sound()
    assert calls == [["canberra-gtk-play", "-i", "message-new-instant"]]


def test_play_sound_falls_back_to_paplay(monkeypatch):
    calls = []
    monkeypatch.setattr(alerts, "_spawn", calls.append)
    monkeypatch.setattr(alerts.shutil, "which", lambda name: None)
    alerts.play_sound()
    assert calls == [["paplay", alerts.SOUND_FILE]]


def test_notify_passes_app_and_urgency(monkeypatch):
    calls = []
    monkeypatch.setattr(alerts, "_spawn", calls.append)
    alerts.notify("Summary", "Body")
    argv = calls[0]
    assert argv[0] == "notify-send"
    assert "Prayer Times" in argv
    assert "Summary" in argv and "Body" in argv
