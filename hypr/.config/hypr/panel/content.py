"""Prayer-times panel content.

Layout priorities, in order:
  1. What do I need to do next, and how long have I got?
  2. The full day's adhan and iqama times, aligned so they can't be misread.
  3. Everything else (clock, dates, source) stays quiet.

Adhan and iqama are visually distinct — different column, different weight,
different colour — because confusing them is the one error that actually costs
you a prayer.

build() is called fresh on every show, so the clock and countdown are always
current. Keep it cheap: no network, no disk beyond the cached timetable.
"""

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

import prayer
import timetable

LOCATION = "Wadi al-Joz, Jerusalem"

# Sunrise is not a prayer, but it closes the Fajr window, so it earns a line.
ROW_ORDER = ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")


def _label(text, *classes, xalign=0.0):
    label = Gtk.Label(label=text)
    label.set_xalign(xalign)
    for name in classes:
        label.add_css_class(name)
    return label


def _hero(schedule: dict) -> Gtk.Widget:
    """The single most useful line: what is imminent."""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    box.add_css_class("pt-hero")

    if schedule["in_iqama_window"]:
        # Adhan has been called; the congregation is forming. This beats
        # anything else on the panel for urgency.
        name = schedule["current_prayer"]
        box.add_css_class("pt-hero-urgent")
        caption = "IQAMA IN"
        big = prayer.format_countdown(schedule["until_iqama"])
        detail = (f"{prayer.DISPLAY_NAMES[name]} "
                  f"{schedule['times'][name]:%H:%M}"
                  f"  →  iqama {schedule['iqamas'][name]:%H:%M}")
    else:
        name = schedule["next_prayer"]
        caption = "NEXT" + (" (tomorrow)" if schedule["next_is_tomorrow"] else "")
        big = prayer.format_countdown(schedule["until_next"])
        detail = (f"{prayer.DISPLAY_NAMES[name]} "
                  f"{schedule['next_time']:%H:%M}"
                  f"  →  iqama {schedule['next_iqama']:%H:%M}")

    top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    top.append(_label(caption, "pt-hero-caption"))
    top.append(_label(prayer.ARABIC_NAMES[name], "pt-hero-arabic"))
    box.append(top)
    box.append(_label(big, "pt-hero-big"))
    box.append(_label(detail, "pt-hero-detail"))
    return box


def _table(schedule: dict) -> Gtk.Widget:
    grid = Gtk.Grid(column_spacing=26, row_spacing=6)
    grid.add_css_class("pt-grid")

    grid.attach(_label("", "pt-head"), 0, 0, 1, 1)
    grid.attach(_label("", "pt-head"), 1, 0, 1, 1)
    grid.attach(_label("ADHAN", "pt-head", xalign=1.0), 2, 0, 1, 1)
    grid.attach(_label("IQAMA", "pt-head", "pt-head-iqama", xalign=1.0), 3, 0, 1, 1)

    row = 1
    for name in ROW_ORDER:
        when = schedule["times"][name]

        if name == "sunrise":
            # Not a prayer: no iqama, and styled as a divider so the eye does
            # not read it as one of the five.
            grid.attach(_label(prayer.DISPLAY_NAMES[name], "pt-sunrise"), 0, row, 2, 1)
            grid.attach(_label(f"{when:%H:%M}", "pt-sunrise", xalign=1.0), 2, row, 1, 1)
            grid.attach(_label("—", "pt-sunrise", xalign=1.0), 3, row, 1, 1)
            row += 1
            continue

        is_next = (name == schedule["next_prayer"]
                   and not schedule["in_iqama_window"]
                   and not schedule["next_is_tomorrow"])
        is_active = schedule["in_iqama_window"] and name == schedule["current_prayer"]
        is_past = when <= schedule["now"] and not is_active

        state = []
        if is_next or is_active:
            state.append("pt-row-live")
        elif is_past:
            state.append("pt-row-past")

        marker = "▶" if (is_next or is_active) else ""
        grid.attach(_label(marker, "pt-marker", *state), 0, row, 1, 1)

        name_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        name_box.append(_label(prayer.DISPLAY_NAMES[name], "pt-name", *state))
        name_box.append(_label(prayer.ARABIC_NAMES[name], "pt-arabic", *state))
        grid.attach(name_box, 1, row, 1, 1)

        grid.attach(_label(f"{when:%H:%M}", "pt-adhan", *state, xalign=1.0),
                    2, row, 1, 1)
        grid.attach(_label(f"{schedule['iqamas'][name]:%H:%M}",
                           "pt-iqama", *state, xalign=1.0), 3, row, 1, 1)
        row += 1

    return grid


def _header(schedule: dict) -> Gtk.Widget:
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=18)

    left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    left.append(_label(f"{schedule['now']:%H:%M}", "pt-clock"))
    dates = f"{schedule['now']:%a %d %b %Y}"
    if schedule["hijri"]:
        dates += f"   ·   {schedule['hijri']}"
    left.append(_label(dates, "pt-date"))
    left.set_hexpand(True)
    box.append(left)

    right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    right.set_valign(Gtk.Align.START)
    right.append(_label(LOCATION, "pt-location", xalign=1.0))
    if schedule["source"] != timetable.SOURCE_OFFICIAL:
        # Never let the fallback masquerade as the published timetable.
        right.append(_label("offline · computed ±1 min", "pt-fallback",
                            xalign=1.0))
    box.append(right)
    return box


def build() -> Gtk.Widget:
    """Return the widget tree to place inside the centered card."""
    schedule = timetable.schedule()

    root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
    root.set_hexpand(True)

    root.append(_header(schedule))
    root.append(_hero(schedule))

    # Left-aligned like the header and hero above it, and natural width rather
    # than stretched: stretching pushed the times to the far right edge, so the
    # eye had to travel a long way to pair a name with its time.
    table = _table(schedule)
    table.set_halign(Gtk.Align.START)
    root.append(table)

    return root
