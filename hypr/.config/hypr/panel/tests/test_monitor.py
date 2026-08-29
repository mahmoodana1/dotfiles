import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import monitor

TWO_MONITORS = json.dumps([
    {"name": "eDP-1", "focused": False},
    {"name": "HDMI-A-1", "focused": True},
])


def test_returns_focused_connector():
    assert monitor.focused_connector(TWO_MONITORS) == "HDMI-A-1"


def test_returns_none_when_nothing_focused():
    blob = json.dumps([{"name": "eDP-1", "focused": False}])
    assert monitor.focused_connector(blob) is None


def test_returns_none_on_invalid_json():
    assert monitor.focused_connector("not json") is None


def test_returns_none_on_empty_list():
    assert monitor.focused_connector("[]") is None


def test_tolerates_missing_focused_key():
    blob = json.dumps([{"name": "eDP-1"}])
    assert monitor.focused_connector(blob) is None


def test_first_focused_wins_if_several():
    blob = json.dumps([
        {"name": "eDP-1", "focused": True},
        {"name": "HDMI-A-1", "focused": True},
    ])
    assert monitor.focused_connector(blob) == "eDP-1"
