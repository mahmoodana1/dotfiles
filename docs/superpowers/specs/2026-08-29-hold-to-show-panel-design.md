# Hold-to-Show HUD Panel — Design

**Date:** 2026-08-29
**Status:** Approved, pending implementation plan
**Target:** Hyprland 0.56.2, Arch. Two monitors: eDP-1 @ 1920x1080 at 0,0 and
HDMI-A-1 @ 1920x1080 at 1920,0, both scale 1.

## Problem

Pressing `SUPER+SHIFT+P` should make a panel appear. Releasing the combination
should make it disappear. The panel is a read-only glance HUD: it is never
typed into and must never take keyboard focus. Content comes later — this
design delivers the show/hide mechanism plus an empty, styled shell ready to
be populated.

## Decisions

| Question | Decision |
|---|---|
| Interaction model | Strictly momentary. Visible only while held. No pinning, no interaction. |
| Focus | Never. Enforced structurally via layer-shell `keyboard_mode = NONE`. |
| Footprint | Centered card ~60%x60%, dimmed backdrop over the rest of the screen. |
| Renderer | Python 3 + GTK4 + `Gtk4LayerShell`. |
| Process model | Resident daemon started at login; keybind only toggles visibility. |
| Monitor | Follows the focused monitor. One surface, remapped on show. |

### Why a resident daemon

Two alternatives were considered and rejected:

- **Spawn on press, kill on release.** No daemon to manage, but GTK+Python cold
  start is roughly 200-400ms. A peek frequently lasts less than that, so the
  panel would often appear only after release, or not at all. This defeats the
  single requirement.
- **Terminal on a special workspace with `no_focus`.** Reuses the existing
  `scripts/Dropterminal.sh` pattern and is cheapest to build. Rejected because
  a normal window can still acquire focus on some code paths, special-workspace
  transitions animate on their own schedule, and a centered card with a dimmed
  backdrop is not something a terminal renders.

With a resident daemon the surface is realized once at login. Show/hide is a
single `set_visible()` on an existing surface — sub-frame latency, no spawn cost.

## Environment (verified 2026-08-29)

- `python3`, GTK 3.0, GTK 4.0 all import via PyGObject.
- `Gtk4LayerShell-1.0.typelib` and `GtkLayerShell-0.1.typelib` present.
- `gtk4-layer-shell 1.3.0`, `gtk-layer-shell 0.10.1` installed from `extra`.
- `SUPER+SHIFT+P` is unbound. `SUPER+P` is `pseudo`, `CTRL+ALT+P` is powermenu.
- `hl.bind` options include `release`, `repeating`, `transparent`,
  `ignore_mods`, `non_consuming`, `long_press` (`/usr/share/hypr/stubs/hl.meta.lua`).
- `input:repeat_delay = 300`, `input:repeat_rate = 50`.
- `ags` is installed but broken (gjs cannot find `GIRepository-2.0` typelib).
  Not used by this design.
- No `wtype` / `ydotool` / `dotool`, so keypresses cannot be synthesized for
  automated testing. Hold-behaviour tests are manual.
- `~/.config/hypr` is a stow symlink to `~/dotfiles/hypr/.config/hypr`, so files
  written under `~/.config/hypr/` land in the dotfiles repo automatically.

## Architecture

Five files, each with a single responsibility.

```
~/.config/hypr/panel/panel.py      daemon: surface, signals, watchdog
~/.config/hypr/panel/content.py    widget tree inside the card  <- populate here
~/.config/hypr/panel/panel.css     styling
~/.config/hypr/panel/panelctl.sh   show/hide helper invoked by the keybinds
~/.config/hypr/lua/panel.lua       keybinds + layer rule
```

`~/.config/hypr/hyprland.lua` gains `require("panel")`, matching the existing
`require("dojo")` line. `~/.config/hypr/lua/startup.lua` gains an `exec-once`
entry for the daemon.

### Module boundary

`content.py` exports exactly one function:

```python
def build() -> Gtk.Widget:
    """Return the widget tree to place inside the centered card."""
```

`panel.py` imports `content` and calls `build()` once at startup. It knows
nothing else about content. Populating the panel later means editing only
`content.py`; the show/hide machinery is never touched.

This boundary is the point of the whole design. It should be possible to
rewrite `content.py` entirely without reading `panel.py`.

### Surface configuration

| Property | Value | Reason |
|---|---|---|
| Layer | `OVERLAY` | Above normal windows and waybar. |
| Anchors | all four edges | Surface fills the screen so the dim covers everything. |
| `exclusive_zone` | `-1` | Ignore waybar's 43px reservation; dim reaches the top edge. |
| `keyboard_mode` | `NONE` | Structurally cannot take focus. |
| Namespace | `hudpanel` | Lets Hyprland target it with a layer rule. |

Visual structure: the full-screen surface paints a translucent dim; a centered
child sized 60%x60% is the card.

Colors follow the desktop theme. `~/.config/hypr/lua/colors.lua` is the wallust
output, but it is a Lua table and Python cannot import it. At startup `panel.py`
reads that file and extracts the `name = "rgb(RRGGBB)"` pairs with a regular
expression, then prepends them to `panel.css` as `@define-color` declarations
(`@define-color color0 #000511;` and so on). `panel.css` refers to the palette
only through those names, never through literal hex values. A wallust theme
change therefore requires only a daemon restart, and if `colors.lua` is missing
or unparseable the daemon falls back to a hardcoded neutral palette rather than
failing to start.

A layer rule enables compositor blur, mirroring the existing rofi rules:

```lua
hl.layer_rule({ match = { namespace = "hudpanel" }, blur = true })
hl.layer_rule({ match = { namespace = "hudpanel" }, ignore_alpha = 0 })
```

### Monitor targeting (verified)

The HUD appears on whichever monitor has focus, so it shows up where the user is
already looking. A single surface is remapped rather than keeping one surface
per monitor.

On show, the daemon:

1. Reads the focused connector via
   `hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name'`
   (called through `subprocess`, not a shell pipeline).
2. Matches it against `Gdk.Display.get_monitors()` by
   `Gdk.Monitor.get_connector()`. These names match Hyprland's exactly —
   confirmed as `eDP-1` and `HDMI-A-1` on this machine.
3. Calls `LS.set_monitor(win, monitor)` while the surface is hidden, then shows.

`set_monitor` across an unmap/remap cycle was verified working on 2026-08-29:
the surface reported `('HDMI-A-1', 1920, 0, 1920, 1080)` and then
`('eDP-1', 0, 0, 1920, 1080)` in `hyprctl layers -j`. Because the surface is
already realized, the remap is a map/unmap rather than a process start.

If the focused monitor cannot be determined (`hyprctl` missing, unexpected JSON,
no connector match) the daemon shows on the last known good monitor, or GTK's
default if there is none. Failing to resolve a monitor must never mean failing
to show.

### Control channel

The daemon writes its PID to `$XDG_RUNTIME_DIR/hypr-panel.pid`. Control is by
UNIX signal, handled inside the GLib main loop via `GLib.unix_signal_add`:

- `SIGUSR1` — show (and reset the watchdog, see below)
- `SIGUSR2` — hide

A helper `~/.config/hypr/panel/panelctl.sh {show|hide}` reads the PID file and
signals it. If the PID file is absent or the process is gone, it exits 0
silently — a missing daemon must never make the keybind produce an error.

## The release-bind risk

Hyprland release binds have a documented failure mode: releasing the modifier
before the key can drop the release event. If that happens here, the panel stays
on screen with no obvious way to dismiss it — the worst possible outcome for a
fullscreen dimmed overlay.

This cannot be pre-tested from a script: no key-injection tool is installed, so
it requires manual keypresses.

**Therefore the implementation leads with a spike**, before any GTK code is
written. Two throwaway binds log a timestamp and a label to
`/tmp/panel-spike.log` on press and on release. The following cases are
exercised by hand and the log inspected:

1. Release `P` first, then `SUPER`/`SHIFT`
2. Release `SUPER` first, then `P`
3. Release `SHIFT` first, then `P`, then `SUPER`
4. Release everything simultaneously
5. Hold for 5 seconds, then release
6. Press and release rapidly 20 times

The watchdog design is then chosen mechanically from the spike result:

- **All six cases fire the release bind** → no watchdog. Release bind alone.
- **Some case reliably misses** → watchdog fed by a heartbeat: the press bind
  gets `repeating = true`, so it re-fires at `repeat_rate` (50/s after a 300ms
  `repeat_delay`). The daemon hides itself 450ms after the last `SIGUSR1`.
  Cost: 50 `panelctl.sh` spawns per second while held. Acceptable but not free;
  if it proves noticeable, the heartbeat moves into a Lua callback that writes
  to a FIFO the daemon polls, avoiding process spawns.
- **Behaviour is inconsistent or unreproducible** → both: release bind as fast
  path, heartbeat watchdog as guarantee.

In every branch except the first, the watchdog ships in the initial version.

### LD_PRELOAD is mandatory (verified)

`gtk4-layer-shell` must be loaded before GTK4 initializes. Under PyGObject this
is not optional and not merely a warning — it silently produces an ordinary
toplevel window instead of a layer surface.

Measured on this machine, 2026-08-29, with a probe that asked Hyprland itself
whether the namespace appeared in `hyprctl layers`:

| Invocation | Result |
|---|---|
| `python3 panel.py` | 8x `GtkWindow is not a layer surface` warning, **NOT A LAYER SURFACE** |
| `LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 panel.py` | **LAYER SURFACE CONFIRMED** |

Note that `/usr/lib/liblayer-shell-preload.so` is a *different* helper and does
not work for this. The correct value is `/usr/lib/libgtk4-layer-shell.so`.

Consequences:

- `panel.py` re-executes itself with the correct `LD_PRELOAD` if it detects the
  variable is unset, so the daemon is correct however it is launched. It must
  not rely on the caller getting this right.
- Startup and `--oneshot` must both go through that path.
- A startup self-check calls `Gtk4LayerShell.is_layer_window()` immediately after
  configuring the surface and exits non-zero if it returns false. This is a
  direct API check and needs no `hyprctl` round trip. Silent degradation to a
  focusable window is the exact failure this design exists to prevent.

The GTK3 + `GtkLayerShell-0.1` path remains available as a fallback (both
typelibs import cleanly) but is not needed.

## Error handling

| Condition | Behaviour |
|---|---|
| Daemon not running | `panelctl.sh` exits 0 silently. Keybind is a no-op. |
| Stale PID file | `panelctl.sh` detects the dead PID, removes the file, exits 0. |
| `content.build()` raises | `panel.py` catches, renders a visible error string in the card, and keeps running. A broken content edit must not kill the daemon. |
| Layer-shell unavailable | `panel.py` logs and exits non-zero at startup rather than falling back to a focusable normal window. |

## Testing

- `panel.py --oneshot` renders the card and exits, for iterating on `content.py`
  and `panel.css` without the keybind or the daemon.
- `Hyprland --verify-config` after every edit to `panel.lua`, per the existing
  convention in this config.
- Manual hold-test matrix (the six cases above) against the finished panel, not
  just the spike.
- Focus assertion: with the panel held open, confirm `hyprctl activewindow`
  still reports the previously focused window.

## Out of scope

- Panel content. `content.py` ships as a placeholder.
- Show/hide animation. The surface appears and disappears immediately. Adding a
  fade is a `content.py`/CSS concern and can come later without touching
  `panel.py`.
- Any interactive or pinned mode. Explicitly rejected.
