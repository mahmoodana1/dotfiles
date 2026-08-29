"""The widget tree inside the card.

This is the file to edit when populating the panel. `build()` is the only
contract: return a single Gtk.Widget. panel.py knows nothing else about it.
"""

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk


def build() -> Gtk.Widget:
    """Return the widget tree to place inside the centered card."""
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    box.set_valign(Gtk.Align.CENTER)
    box.set_halign(Gtk.Align.CENTER)

    title = Gtk.Label(label="HUD Panel")
    title.add_css_class("panel-title")
    box.append(title)

    hint = Gtk.Label(label="hold SUPER+SHIFT+P")
    hint.add_css_class("panel-hint")
    box.append(hint)

    return box
