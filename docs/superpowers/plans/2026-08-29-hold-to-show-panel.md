# Hold-to-Show HUD Panel Implementation Plan

> **Post-implementation corrections (2026-08-29).** Three defects in the Task 5
> code below were found during execution and fixed in the shipped
> `~/.config/hypr/panel/panel.py`. If this plan is ever re-run, apply these:
>
> 1. **Card was left-aligned, not centred.** The card needs
>    `set_hexpand(True)` / `set_vexpand(True)` *in addition to*
>    `halign/valign = CENTER`. Without the expands, the horizontal `Gtk.Box`
>    allocates only the card's natural width and packs it against the left
>    edge, so `halign` has no slack to centre within. Verified fixed: card
>    1152x648 at (384,216) on 1920x1080, margins 384/384 and 216/216.
> 2. **`--oneshot` silently did nothing while the daemon ran.**
>    `Gtk.Application` is single-instance per `application_id` over D-Bus, so a
>    second process forwarded an activate to the daemon and exited 0 without
>    rendering. Fixed by passing `Gio.ApplicationFlags.NON_UNIQUE` in oneshot
>    mode. This broke the documented `content.py` iteration workflow.
> 3. **Missing `gi.require_version("Gdk", "4.0")`** produced a `PyGIWarning` on
>    every start.
>
> Also added: `Panel.report_geometry()`, called in `--oneshot`, which prints the
> card's allocation and margins so centring is verified numerically rather than
> by eye. It must read dimensions from the monitor geometry — a layer surface
> reports `0x0` from `window.get_width()`.


> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pressing and holding `SUPER+SHIFT+P` shows a centered, dimmed-backdrop HUD on the focused monitor; releasing hides it. The HUD never takes keyboard focus.

**Architecture:** A resident Python/GTK4 daemon owns a `zwlr-layer-shell` overlay surface created once at login and kept hidden. Hyprland keybinds signal the daemon (`SIGUSR1` show, `SIGUSR2` hide) via a small shell helper, so show/hide is a `set_visible()` on an already-realized surface rather than a process spawn. Pure logic (palette parsing, monitor resolution) lives in separate modules so it is unit-testable without a display.

**Tech Stack:** Python 3, PyGObject, GTK 4.22.4, `gtk4-layer-shell` 1.3.0, pytest 9.0.3, Hyprland 0.56.2 Lua config.

---

## Preconditions (verified 2026-08-29, do not re-litigate)

- `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so` is **mandatory**. Without it the window silently becomes an ordinary focusable toplevel. `/usr/lib/liblayer-shell-preload.so` is a different helper and does **not** work.
- `LS.set_monitor()` survives an unmap/remap cycle. Verified moving a surface HDMI-A-1 → eDP-1.
- `Gdk.Monitor.get_connector()` returns names matching Hyprland's (`eDP-1`, `HDMI-A-1`).
- `SUPER+SHIFT+P` is unbound. `SUPER+P` is `pseudo`; `CTRL+ALT+P` is powermenu.
- `input:repeat_delay = 300`, `input:repeat_rate = 50`.
- `~/.config/hypr` is a stow symlink to `~/dotfiles/hypr/.config/hypr`. Writing to the former writes into the git repo.

## Git note

The repo `~/dotfiles` is on `main` and already contains unrelated modifications
(`cli/.config/psd/.psd.conf`, `shell/.zshrc`) that predate this work. The user
declined committing the design spec. Commit steps below are therefore **opt-in**:
if the user wants commits, create a branch first and stage only the listed paths —
never `git add -A`.

## File Structure

| File | Responsibility |
|---|---|
| `~/.config/hypr/panel/panel.py` | Daemon. Preload re-exec, layer surface, signals, show/hide, watchdog. |
| `~/.config/hypr/panel/theme.py` | Pure: parse `colors.lua`, assemble CSS. No GTK import. |
| `~/.config/hypr/panel/monitor.py` | Pure: resolve focused connector from `hyprctl` JSON. No GTK import. |
| `~/.config/hypr/panel/content.py` | Widget tree inside the card. **The file to populate later.** |
| `~/.config/hypr/panel/panel.css` | Styling. References palette only via `@define-color` names. |
| `~/.config/hypr/panel/panelctl.sh` | Reads PID file, sends signal. Silent no-op if daemon absent. |
| `~/.config/hypr/panel/tests/test_theme.py` | Unit tests for `theme.py`. |
| `~/.config/hypr/panel/tests/test_monitor.py` | Unit tests for `monitor.py`. |
| `~/.config/hypr/lua/panel.lua` | Keybinds + layer rule. |
| `~/.config/hypr/hyprland.lua` | Modify: add `require("panel")`. |
| `~/.config/hypr/lua/startup.lua` | Modify: autostart the daemon. |

The spec named five files; `theme.py` and `monitor.py` are split out from
`panel.py` so the two pieces of real logic can be tested headlessly. Everything
GTK-dependent stays in `panel.py`, which is verified by hand.

---

## Task 1: Settle release-bind semantics (spike)

This gates the watchdog decision in Task 10. Do it first — the answer changes
what ships.

**Files:**
- Create: `~/.config/hypr/lua/panel.lua` (temporary contents, replaced in Task 8)
- Modify: `~/.config/hypr/hyprland.lua`

- [ ] **Step 1: Write the logging binds**

Create `~/.config/hypr/lua/panel.lua`:

```lua
-- TEMPORARY spike config. Replaced in Task 8.
local d = require("defaults")
local mod = d.mainMod

local function log(tag)
    return hl.dsp.exec_cmd(
        "sh -c 'printf \"%s %s\\n\" \"$(date +%s.%N)\" " .. tag .. " >> /tmp/panel-spike.log'")
end

hl.bind(mod .. " + SHIFT + P", log("PRESS"),   { description = "spike press" })
hl.bind(mod .. " + SHIFT + P", log("RELEASE"), { description = "spike release", release = true })
```

- [ ] **Step 2: Wire it in**

Add to `~/.config/hypr/hyprland.lua` after the `require("dojo")` line:

```lua
require("panel")         -- hold-to-show HUD panel
```

- [ ] **Step 3: Verify the config parses**

Run: `Hyprland --verify-config`
Expected: no errors mentioning `panel.lua`.

- [ ] **Step 4: Reload and clear the log**

```bash
rm -f /tmp/panel-spike.log && hyprctl reload && echo reloaded
```
Expected: `reloaded`

- [ ] **Step 5: Run the manual matrix**

**This step needs the user's fingers — there is no key-injection tool installed.**
Ask the user to perform each case, pausing about a second between cases:

1. Hold `SUPER+SHIFT+P`, release `P` first, then the modifiers
2. Hold, release `SUPER` first, then `P`
3. Hold, release `SHIFT` first, then `P`, then `SUPER`
4. Hold, release everything simultaneously
5. Hold 5 seconds, then release
6. Press and release rapidly 20 times

- [ ] **Step 6: Read the result**

```bash
cat /tmp/panel-spike.log
awk '{print $2}' /tmp/panel-spike.log | sort | uniq -c
```
Expected if release binds are reliable: `PRESS` and `RELEASE` counts are equal
(26 each, given 6 cases where case 6 contributes 20).
A `RELEASE` deficit identifies which case drops events.

- [ ] **Step 7: Record the verdict**

Write the outcome into the plan file under Task 10 as one of:
`WATCHDOG: not needed` / `WATCHDOG: required` / `WATCHDOG: required (inconsistent)`.
Do not proceed to Task 10 without this line.

---

## Task 2: Palette parsing

**Files:**
- Create: `~/.config/hypr/panel/theme.py`
- Create: `~/.config/hypr/panel/tests/test_theme.py`

- [ ] **Step 1: Write the failing tests**

Create `~/.config/hypr/panel/tests/test_theme.py`:

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import theme

SAMPLE = '''
-- Colors generated by wallust.
return {
    background = "rgb(00010E)",
    foreground = "rgb(E1E4E9)",
    color0     = "rgb(000511)",
    color7     = "rgb(CCD0D7)",
}
'''


def test_parses_named_colors():
    palette = theme.parse_palette(SAMPLE)
    assert palette["background"] == "#00010E"
    assert palette["foreground"] == "#E1E4E9"
    assert palette["color0"] == "#000511"
    assert palette["color7"] == "#CCD0D7"


def test_ignores_comments_and_non_color_lines():
    palette = theme.parse_palette(SAMPLE)
    assert "generated" not in palette
    assert len(palette) == 4


def test_returns_empty_on_garbage():
    assert theme.parse_palette("this is not lua") == {}


def test_fallback_used_when_palette_empty():
    css = theme.build_css("", "window { background: @background; }")
    assert "@define-color background" in css
    assert "window { background: @background; }" in css


def test_build_css_prepends_definitions():
    css = theme.build_css(SAMPLE, "card { color: @foreground; }")
    assert "@define-color foreground #E1E4E9;" in css
    assert css.index("@define-color") < css.index("card {")


def test_load_palette_text_missing_file_returns_empty(tmp_path):
    assert theme.load_palette_text(tmp_path / "nope.lua") == ""
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/.config/hypr/panel && python3 -m pytest tests/test_theme.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'theme'`

- [ ] **Step 3: Write the implementation**

Create `~/.config/hypr/panel/theme.py`:

```python
"""Palette parsing and CSS assembly. Pure logic — imports no GTK."""

import re
from pathlib import Path

# Matches:  name       = "rgb(RRGGBB)",
_COLOR_RE = re.compile(r'^\s*(\w+)\s*=\s*"rgb\(([0-9A-Fa-f]{6})\)"', re.MULTILINE)

# Used when colors.lua is missing or unparseable. Neutral dark, readable.
FALLBACK = {
    "background": "#11121A",
    "foreground": "#E1E4E9",
    "color0": "#11121A",
    "color7": "#CCD0D7",
    "color8": "#8F9196",
}


def load_palette_text(path) -> str:
    """Read colors.lua. Returns '' if it is missing or unreadable."""
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError:
        return ""


def parse_palette(text: str) -> dict:
    """Extract {name: '#RRGGBB'} from wallust's colors.lua text."""
    return {name: "#" + value.upper() for name, value in _COLOR_RE.findall(text)}


def build_css(palette_text: str, css_body: str) -> str:
    """Prepend @define-color declarations to the stylesheet body."""
    palette = parse_palette(palette_text) or dict(FALLBACK)
    for name, value in FALLBACK.items():
        palette.setdefault(name, value)
    defs = "\n".join(f"@define-color {n} {v};" for n, v in sorted(palette.items()))
    return f"{defs}\n\n{css_body}"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/.config/hypr/panel && python3 -m pytest tests/test_theme.py -v`
Expected: 6 passed

- [ ] **Step 5: Commit (opt-in — see Git note)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/theme.py hypr/.config/hypr/panel/tests/test_theme.py
git -C ~/dotfiles commit -m "feat(panel): palette parsing and CSS assembly

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Focused-monitor resolution

**Files:**
- Create: `~/.config/hypr/panel/monitor.py`
- Create: `~/.config/hypr/panel/tests/test_monitor.py`

- [ ] **Step 1: Write the failing tests**

Create `~/.config/hypr/panel/tests/test_monitor.py`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/.config/hypr/panel && python3 -m pytest tests/test_monitor.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'monitor'`

- [ ] **Step 3: Write the implementation**

Create `~/.config/hypr/panel/monitor.py`:

```python
"""Focused-monitor resolution. Pure logic — imports no GTK."""

import json
import subprocess


def focused_connector(hyprctl_json: str):
    """Return the focused monitor's connector name, or None."""
    try:
        monitors = json.loads(hyprctl_json)
    except (ValueError, TypeError):
        return None
    if not isinstance(monitors, list):
        return None
    for entry in monitors:
        if isinstance(entry, dict) and entry.get("focused") is True:
            name = entry.get("name")
            return name if isinstance(name, str) else None
    return None


def query_focused_connector():
    """Ask Hyprland which monitor has focus. Returns None on any failure."""
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, timeout=1.0,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return focused_connector(result.stdout)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/.config/hypr/panel && python3 -m pytest tests/test_monitor.py -v`
Expected: 6 passed

- [ ] **Step 5: Verify the live query against the real compositor**

Run: `cd ~/.config/hypr/panel && python3 -c "import monitor; print(monitor.query_focused_connector())"`
Expected: `eDP-1` or `HDMI-A-1` — matches `hyprctl monitors -j | jq -r '.[]|select(.focused)|.name'`

- [ ] **Step 6: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/monitor.py hypr/.config/hypr/panel/tests/test_monitor.py
git -C ~/dotfiles commit -m "feat(panel): focused-monitor resolution

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Placeholder content and stylesheet

**Files:**
- Create: `~/.config/hypr/panel/content.py`
- Create: `~/.config/hypr/panel/panel.css`

- [ ] **Step 1: Write the content module**

Create `~/.config/hypr/panel/content.py`:

```python
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
```

- [ ] **Step 2: Write the stylesheet**

Create `~/.config/hypr/panel/panel.css`:

```css
/* Palette names (@background, @foreground, @color0 ...) are injected at
   runtime by theme.build_css() from wallust's colors.lua. Never hardcode hex. */

window.hudpanel {
  background: transparent;
}

.panel-dim {
  background: alpha(black, 0.45);
}

.panel-card {
  background: alpha(@background, 0.92);
  border: 1px solid alpha(@color8, 0.35);
  border-radius: 18px;
  padding: 28px;
}

.panel-title {
  color: @foreground;
  font-size: 22px;
  font-weight: 700;
}

.panel-hint {
  color: alpha(@color8, 0.85);
  font-size: 13px;
}
```

- [ ] **Step 3: Verify the content module imports cleanly**

Run: `cd ~/.config/hypr/panel && LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 -c "import content; print(content.build())"`
Expected: something like `<Gtk.Box object at 0x...>` and no traceback

- [ ] **Step 4: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/content.py hypr/.config/hypr/panel/panel.css
git -C ~/dotfiles commit -m "feat(panel): placeholder content and stylesheet

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: The daemon

**Files:**
- Create: `~/.config/hypr/panel/panel.py`

- [ ] **Step 1: Write the daemon**

Create `~/.config/hypr/panel/panel.py`:

```python
#!/usr/bin/env python3
"""Hold-to-show HUD panel daemon.

Owns a layer-shell overlay surface, kept hidden until signalled:
  SIGUSR1 -> show on the focused monitor
  SIGUSR2 -> hide
"""

import os
import sys

# gtk4-layer-shell MUST be loaded before GTK4 initialises. Without this the
# window silently becomes an ordinary focusable toplevel. Re-exec ourselves so
# the daemon is correct however it was launched.
PRELOAD = "/usr/lib/libgtk4-layer-shell.so"


def _ensure_preload() -> None:
    current = os.environ.get("LD_PRELOAD", "")
    if PRELOAD in current.split(":"):
        return
    os.environ["LD_PRELOAD"] = f"{PRELOAD}:{current}" if current else PRELOAD
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__), *sys.argv[1:]])


_ensure_preload()

import signal  # noqa: E402

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LS  # noqa: E402

import content  # noqa: E402
import monitor  # noqa: E402
import theme  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
NAMESPACE = "hudpanel"
APP_ID = "dev.mahmood.hudpanel"
COLORS_LUA = os.path.join(HERE, "..", "lua", "colors.lua")
CSS_FILE = os.path.join(HERE, "panel.css")
PID_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr-panel.pid")
CARD_FRACTION = 0.6  # card is 60% of the monitor in both axes


def log(message: str) -> None:
    print(f"[hudpanel] {message}", file=sys.stderr, flush=True)


class Panel:
    def __init__(self, app: Gtk.Application, oneshot: bool = False):
        self.app = app
        self.oneshot = oneshot
        self.window = None
        self.card = None
        self.last_monitor = None

    def build(self) -> None:
        self.window = Gtk.Window()
        self.window.add_css_class("hudpanel")

        LS.init_for_window(self.window)
        LS.set_layer(self.window, LS.Layer.OVERLAY)
        LS.set_namespace(self.window, NAMESPACE)
        LS.set_keyboard_mode(self.window, LS.KeyboardMode.NONE)
        for edge in (LS.Edge.TOP, LS.Edge.BOTTOM, LS.Edge.LEFT, LS.Edge.RIGHT):
            LS.set_anchor(self.window, edge, True)
        LS.set_exclusive_zone(self.window, -1)

        if not LS.is_layer_window(self.window):
            log("FATAL: not a layer surface. Is LD_PRELOAD set correctly?")
            sys.exit(1)

        dim = Gtk.Box()
        dim.add_css_class("panel-dim")
        dim.set_hexpand(True)
        dim.set_vexpand(True)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        card.add_css_class("panel-card")
        card.set_halign(Gtk.Align.CENTER)
        card.set_valign(Gtk.Align.CENTER)

        # A broken content.py must not kill the daemon.
        try:
            card.append(content.build())
        except Exception as exc:  # noqa: BLE001 - deliberate catch-all
            log(f"content.build() failed: {exc!r}")
            card.append(Gtk.Label(label=f"content error:\n{exc}"))

        dim.append(card)
        self.card = card
        self.window.set_child(dim)
        self.app.add_window(self.window)

    def _size_card(self, mon) -> None:
        """Size the card to CARD_FRACTION of the monitor. Natural size otherwise."""
        if mon is None or self.card is None:
            return
        geo = mon.get_geometry()
        self.card.set_size_request(
            int(geo.width * CARD_FRACTION), int(geo.height * CARD_FRACTION)
        )

    def load_css(self) -> None:
        try:
            body = open(CSS_FILE, encoding="utf-8").read()
        except OSError as exc:
            log(f"cannot read panel.css: {exc}")
            return
        css = theme.build_css(theme.load_palette_text(COLORS_LUA), body)
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def _target_monitor(self):
        name = monitor.query_focused_connector()
        display = Gdk.Display.get_default()
        if name:
            for mon in display.get_monitors():
                if mon.get_connector() == name:
                    self.last_monitor = mon
                    return mon
            log(f"focused connector {name!r} not found in GDK monitors")
        return self.last_monitor

    def show(self) -> None:
        if self.window.get_visible():
            return
        target = self._target_monitor()
        if target is not None:
            LS.set_monitor(self.window, target)
        self._size_card(target)
        self.window.set_visible(True)

    def hide(self) -> None:
        if self.window.get_visible():
            self.window.set_visible(False)


def main() -> int:
    oneshot = "--oneshot" in sys.argv[1:]
    app = Gtk.Application(application_id=APP_ID)
    panel = Panel(app, oneshot=oneshot)

    def on_activate(_app):
        panel.build()
        panel.load_css()

        if oneshot:
            panel.show()
            GLib.timeout_add(3000, lambda: (app.quit(), False)[1])
            return

        app.hold()  # stay alive with no visible window
        with open(PID_FILE, "w", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))

        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1,
                             lambda: (panel.show(), True)[1])
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR2,
                             lambda: (panel.hide(), True)[1])
        log(f"ready, pid {os.getpid()}")

    app.connect("activate", on_activate)
    try:
        return app.run([])
    finally:
        if not oneshot:
            try:
                os.unlink(PID_FILE)
            except OSError:
                pass


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ~/.config/hypr/panel/panel.py
```

- [ ] **Step 3: Verify --oneshot renders a real layer surface**

Terminal A:
```bash
~/.config/hypr/panel/panel.py --oneshot
```
Terminal B, while it is up:
```bash
hyprctl layers | grep hudpanel
```
Expected: a line containing `namespace: hudpanel`. No `is not a layer surface`
warnings. On screen for ~3s: a dimmed full-screen backdrop with a rounded card
centered on it, the card roughly 60% of the screen in each axis (about
1152x648 on these 1920x1080 monitors) — not shrink-wrapped to the two labels.

- [ ] **Step 4: Verify it does not steal focus**

With `--oneshot` running, in Terminal B:
```bash
hyprctl activewindow -j | jq -r '.class'
```
Expected: the terminal's class, **not** the panel. The panel must never appear
as the active window.

- [ ] **Step 5: Verify signal-driven show/hide**

```bash
~/.config/hypr/panel/panel.py &
sleep 3
kill -USR1 $(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"); sleep 1
hyprctl layers | grep -c hudpanel
kill -USR2 $(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"); sleep 1
hyprctl layers | grep -c hudpanel
kill %1
```
Expected: `1` after SIGUSR1, `0` after SIGUSR2.

- [ ] **Step 6: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/panel.py
git -C ~/dotfiles commit -m "feat(panel): layer-shell daemon with signal control

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Control helper

**Files:**
- Create: `~/.config/hypr/panel/panelctl.sh`

- [ ] **Step 1: Write the helper**

Create `~/.config/hypr/panel/panelctl.sh`:

```bash
#!/usr/bin/env bash
# Show or hide the HUD panel. Exits 0 even when the daemon is absent, so a
# missing daemon never turns a keypress into an error.
set -u

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"

case "${1:-}" in
  show) SIG=USR1 ;;
  hide) SIG=USR2 ;;
  *) echo "usage: $0 {show|hide}" >&2; exit 2 ;;
esac

[ -r "$PID_FILE" ] || exit 0

PID=$(cat "$PID_FILE" 2>/dev/null) || exit 0
case "$PID" in
  ''|*[!0-9]*) exit 0 ;;
esac

if ! kill -0 "$PID" 2>/dev/null; then
  rm -f "$PID_FILE"      # stale
  exit 0
fi

kill -"$SIG" "$PID" 2>/dev/null || true
exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x ~/.config/hypr/panel/panelctl.sh
```

- [ ] **Step 3: Verify it is a silent no-op with no daemon**

```bash
rm -f "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"
~/.config/hypr/panel/panelctl.sh show; echo "exit=$?"
```
Expected: `exit=0`, no output.

- [ ] **Step 4: Verify stale PID cleanup**

```bash
echo 999999 > "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid"
~/.config/hypr/panel/panelctl.sh show; echo "exit=$?"
test -f "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid" && echo "STALE FILE REMAINS" || echo "stale file removed"
```
Expected: `exit=0` then `stale file removed`

- [ ] **Step 5: Verify bad usage is rejected**

```bash
~/.config/hypr/panel/panelctl.sh bogus; echo "exit=$?"
```
Expected: usage line on stderr, `exit=2`

- [ ] **Step 6: Verify it drives the real daemon**

```bash
~/.config/hypr/panel/panel.py & sleep 3
~/.config/hypr/panel/panelctl.sh show; sleep 1; hyprctl layers | grep -c hudpanel
~/.config/hypr/panel/panelctl.sh hide; sleep 1; hyprctl layers | grep -c hudpanel
kill %1
```
Expected: `1` then `0`

- [ ] **Step 7: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/panelctl.sh
git -C ~/dotfiles commit -m "feat(panel): panelctl show/hide helper

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Autostart

**Files:**
- Modify: `~/.config/hypr/lua/startup.lua`

- [ ] **Step 1: Locate the insertion point**

`startup.lua` wraps everything in `hl.on("hyprland.start", function() ... end)`
so entries fire once per session rather than on every reload. Entries use
`hl.exec_cmd(...)` and `d.home` is already in scope via `local d = require("defaults")`.

Run: `grep -n 'hl.exec_cmd("waybar")' ~/.config/hypr/lua/startup.lua`
Expected: one line number. Insert after it, still **inside** the
`hl.on("hyprland.start", ...)` block.

- [ ] **Step 2: Add the autostart entry**

Insert into `~/.config/hypr/lua/startup.lua` after the `hl.exec_cmd("waybar")` line:

```lua
    -- Hold-to-show HUD panel daemon (SUPER+SHIFT+P)
    hl.exec_cmd(d.home .. "/.config/hypr/panel/panel.py")
```

Note the four-space indent — it sits inside the `hl.on` block with its siblings.

- [ ] **Step 3: Verify the config parses**

Run: `Hyprland --verify-config`
Expected: no errors

- [ ] **Step 4: Start it for this session without relogging**

```bash
pkill -f 'panel/panel.py' 2>/dev/null
~/.config/hypr/panel/panel.py >/tmp/hudpanel.log 2>&1 &
sleep 3 && cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid" && grep ready /tmp/hudpanel.log
```
Expected: a PID, and a `[hudpanel] ready, pid N` line

- [ ] **Step 5: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/lua/startup.lua
git -C ~/dotfiles commit -m "feat(panel): autostart the HUD daemon

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Keybinds and layer rule

Replaces the Task 1 spike contents of `panel.lua`.

**Files:**
- Modify: `~/.config/hypr/lua/panel.lua` (full rewrite)

- [ ] **Step 1: Write the real config**

Replace `~/.config/hypr/lua/panel.lua` entirely:

```lua
-- Hold-to-show HUD panel.
-- SUPER+SHIFT+P shows a centered overlay while held; releasing hides it.
-- Daemon: ~/.config/hypr/panel/panel.py (autostarted from startup.lua)
-- Verify after editing:  Hyprland --verify-config

local d = require("defaults")
local mod = d.mainMod
local ctl = os.getenv("HOME") .. "/.config/hypr/panel/panelctl.sh"

hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(ctl .. " show"),
        { description = "HUD panel (hold to show)" })

hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(ctl .. " hide"),
        { description = "HUD panel (hide on release)", release = true })

-- Compositor blur behind the card, mirroring the rofi rules in windowrules.lua.
hl.layer_rule({ match = { namespace = "hudpanel" }, blur = true })
hl.layer_rule({ match = { namespace = "hudpanel" }, ignore_alpha = 0 })
```

- [ ] **Step 2: Verify the config parses**

Run: `Hyprland --verify-config`
Expected: no errors

- [ ] **Step 3: Reload**

Run: `hyprctl reload && echo reloaded`
Expected: `reloaded`

- [ ] **Step 4: Confirm both binds registered**

Run: `hyprctl binds -j | jq -r '.[] | select(.modmask==65 and (.key|ascii_downcase)=="p") | "release=\(.release) desc=\(.description)"'`
Expected: two lines, one `release=false`, one `release=true`

- [ ] **Step 5: Manual check**

Ask the user to hold `SUPER+SHIFT+P`. Expected: card appears on the focused
monitor while held, disappears on release.

- [ ] **Step 6: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/lua/panel.lua hypr/.config/hypr/hyprland.lua
git -C ~/dotfiles commit -m "feat(panel): hold-to-show keybinds and blur layer rule

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: Monitor-follow verification

**Files:** none — verification only.

- [ ] **Step 1: Verify on the laptop screen**

Focus a window on `eDP-1`, then:
```bash
~/.config/hypr/panel/panelctl.sh show; sleep 1
hyprctl layers -j | jq -r 'to_entries[] | .key as $m | .value.levels[][]? | select(.namespace=="hudpanel") | $m'
~/.config/hypr/panel/panelctl.sh hide
```
Expected: `eDP-1`

- [ ] **Step 2: Verify on the external screen**

Focus a window on `HDMI-A-1`, then run the same three commands.
Expected: `HDMI-A-1`

- [ ] **Step 3: Verify the fallback path**

```bash
cd ~/.config/hypr/panel && python3 -c "
import monitor
print('bad json  ->', monitor.focused_connector('nope'))
print('empty     ->', monitor.focused_connector('[]'))
"
```
Expected: both `None` — the daemon then falls back to the last known monitor.

---

## Task 10: Watchdog

**WATCHDOG VERDICT:** `required` — measured 2026-08-29.

33 PRESS vs 30 RELEASE across the six-case matrix (~9% of releases dropped).
Drop sites: one at t=+102.3s that stranded the state for 4.1s, and two during
the rapid-mash case with presses 0.166s / 0.187s apart. Longest well-formed
hold was 4.878s, so long holds themselves are fine — it is fast and
odd-ordered releases that lose the event.

Median hold was 139ms, below the 300ms `repeat_delay`, so typical taps generate
no repeats at all and the heartbeat costs nothing in normal use. Only holds
longer than 300ms heartbeat, and only those pay the spawn cost.

**If the verdict is `not needed`, skip this task entirely** and note in the plan
that the release bind proved reliable across all six cases.

**Files:**
- Modify: `~/.config/hypr/panel/panel.py`
- Modify: `~/.config/hypr/lua/panel.lua`

- [ ] **Step 1: Add the watchdog to the daemon**

In `~/.config/hypr/panel/panel.py`, add to `Panel.__init__`:

```python
        self.watchdog_id = 0
```

Add these methods to `Panel`:

```python
    WATCHDOG_MS = 450  # > input:repeat_delay (300ms), so a held key keeps it alive

    def _cancel_watchdog(self) -> None:
        if self.watchdog_id:
            GLib.source_remove(self.watchdog_id)
            self.watchdog_id = 0

    def _on_watchdog(self) -> bool:
        self.watchdog_id = 0
        log("watchdog fired — no heartbeat, hiding")
        self.hide()
        return False

    def kick_watchdog(self) -> None:
        self._cancel_watchdog()
        self.watchdog_id = GLib.timeout_add(self.WATCHDOG_MS, self._on_watchdog)
```

Change `show()` to kick the watchdog on every call, and make the early return
still kick it (a repeat heartbeat arrives while already visible):

```python
    def show(self) -> None:
        self.kick_watchdog()
        if self.window.get_visible():
            return
        target = self._target_monitor()
        if target is not None:
            LS.set_monitor(self.window, target)
        self._size_card(target)
        self.window.set_visible(True)
```

Change `hide()` to cancel it:

```python
    def hide(self) -> None:
        self._cancel_watchdog()
        if self.window.get_visible():
            self.window.set_visible(False)
```

- [ ] **Step 2: Make the press bind repeat, so it heartbeats**

In `~/.config/hypr/lua/panel.lua`, add `repeating = true` to the press bind only:

```lua
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(ctl .. " show"),
        { description = "HUD panel (hold to show)", repeating = true })
```

- [ ] **Step 3: Verify the config parses and reload**

```bash
Hyprland --verify-config && hyprctl reload && echo reloaded
```
Expected: `reloaded`

- [ ] **Step 4: Verify the watchdog hides a stuck panel**

Simulate a dropped release by sending only a show:
```bash
~/.config/hypr/panel/panelctl.sh show
sleep 1
hyprctl layers | grep -c hudpanel
```
Expected: `0` — the watchdog hid it ~450ms after the single heartbeat.

- [ ] **Step 5: Verify a genuine hold still stays up**

Ask the user to hold `SUPER+SHIFT+P` for 5 seconds. Expected: the panel stays
visible for the whole hold and does not flicker. If it flickers, `WATCHDOG_MS`
is below the effective heartbeat interval — raise it to 700 and retest.

- [ ] **Step 6: Commit (opt-in)**

```bash
git -C ~/dotfiles add hypr/.config/hypr/panel/panel.py hypr/.config/hypr/lua/panel.lua
git -C ~/dotfiles commit -m "feat(panel): watchdog so a dropped release cannot strand the HUD

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 11: Full verification

**Files:** none — verification only.

- [ ] **Step 1: Run the unit tests**

Run: `cd ~/.config/hypr/panel && python3 -m pytest tests/ -v`
Expected: 12 passed

- [ ] **Step 2: Verify the config**

Run: `Hyprland --verify-config`
Expected: no errors

- [ ] **Step 3: Re-run the full hold matrix against the finished panel**

Ask the user to perform each case and report what they see:

| # | Action | Expected |
|---|---|---|
| 1 | Release `P` first | panel hides |
| 2 | Release `SUPER` first | panel hides |
| 3 | Release `SHIFT` first | panel hides |
| 4 | Release all at once | panel hides |
| 5 | Hold 5s | stays up whole time, then hides |
| 6 | Mash 20x rapidly | no stuck panel, no crash |

- [ ] **Step 4: Confirm focus is never stolen**

While holding the panel open, have the user confirm typing still goes to the
previously focused window. Then:
```bash
hyprctl activewindow -j | jq -r '.class'
```
Expected: the underlying window's class, never the panel.

- [ ] **Step 5: Confirm the daemon survived**

```bash
grep -c 'content.build() failed\|FATAL' /tmp/hudpanel.log || true
kill -0 $(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid") && echo "daemon alive"
```
Expected: `0` errors, `daemon alive`

- [ ] **Step 6: Confirm a clean session start**

Ask the user to log out and back in, then:
```bash
sleep 5; cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-panel.pid" && echo "autostarted"
```
Expected: a PID and `autostarted`. Then hold `SUPER+SHIFT+P` once to confirm.
