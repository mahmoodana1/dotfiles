# Glass panels — design

Date: 2026-09-26 · Sub-project 1 of 3 of the "water glass" desktop.

## Goal

Make the desktop's pop-up panels look and move like the Dynamic Island: real
refracting water glass, tinted with the palette's sea blue, pouring down from
the top edge. Replace the rofi launcher, the rofi shortcut viewer, the rofi
wallpaper menus, the rofi window switcher and the GTK HUD panel, and add a power
menu, all as Quickshell panels sharing one glass kit.

Out of scope (later sub-projects, same visual language):
2. Hyprland windows and animations: blur tuning, borders, open/close/workspace
   curves matching the pour motion.
3. Lock screen (hyprlock) and notifications (swaync).

## Decisions (made with the user, visual companion)

| Question | Choice |
|---|---|
| How to build D/H panels | Quickshell + the island's real water shader |
| Launcher layout | Glass grid: centred card, search bar, app icon grid |
| Glass style (all panels) | Sea-tinted: tinted with the palette `accent` color |
| Motion (all panels) | Pours from the top: a thin drop stretches down and settles like jelly; sucked back up on close |
| Shortcut viewer layout | Section tabs on the left, that section's shortcuts on the right; typing searches all |
| Wallpaper | Carousel, centred one large, live preview; effects as chips below |
| Window switcher | Grid of live window previews, all workspaces, type to filter |
| Power menu | Five round buttons; destructive ones need a second press |
| HUD | Same prayer-time content as today, drawn in the glass card |
| Where panels run | One new always-on Quickshell config `glass` |

## Architecture

```
widgets/.config/quickshell/
  common/                    shared glass kit (used by island AND glass)
    WaterGlass.qml             moved from island/; adds tint uniforms
    shaders/water.frag(.qsb)   + tint (rgb) and tintStrength
    GlassCard.qml              ScreencopyView backdrop + GlassLum + WaterGlass + clipped content slot
    PourMotion.qml             open/close animation driver (single place for speed/overshoot)
    Palette.qml                singleton; reads ~/.config/palette/build/palette.json (FileView, watched)
  island/                    existing; imports WaterGlass from ../common
  glass/                     NEW: `qs -c glass`, always running
    shell.qml                  one overlay PanelWindow per monitor + IpcHandler
    Launcher.qml Shortcuts.qml Wallpapers.qml Windows.qml Power.qml Hud.qml
    lib/*.js                   pure logic (parsers, matching, sorting), unit-tested
```

- `island/` and `glass/` reach `common/` through a relative symlink (`common -> ../common`),
  the same way island already links `shared -> ../peek`.
- Each monitor has one always-mapped overlay `PanelWindow` (namespace `glass`,
  layer Overlay, exclusion ignored). Closed: empty input mask and no keyboard
  focus. Open: full mask, exclusive keyboard focus. Same pattern as
  `island/FloatPanel.qml`.
- Panels open on the focused monitor. One panel at a time; opening another swaps.
- IPC target `glass`: `toggle <panel>`, `show <panel>`, `hide <panel>`.
  Panel names: `launcher shortcuts wallpaper windows power hud`.
  `show wallpaper effects` focuses the effect chips (SUPER+SHIFT+W).

### Palette → Quickshell

`palette-apply` gains a template `palette.json` → `~/.config/palette/build/palette.json`
(all palette entries as `#RRGGBB`). `Palette.qml` watches it, so `palette-apply`
restyles open panels live. Tint = `accent`. The island uses the same tint;
its strength is one property in `Palette.qml` (`islandTint`), panels use `panelTint`.

### Motion

`PourMotion` drives a 0→1 progress `t`. Open: ~420 ms, OutBack-style overshoot
with a short vertical squash/settle ("jelly"). The card starts as a narrow pill
at the top-centre (or the island's rect when the island is visible) and
stretches to its final rect. Close: ~240 ms, InCubic, back into the pill.
Durations and overshoot are properties on `PourMotion`.

## Panels

| Panel | Key | Data | Action |
|---|---|---|---|
| Launcher | SUPER+D | `DesktopEntries.applications`; sorted by launch count (`~/.local/state/glass/launches.json`), then name; fuzzy filter on name, keywords, comment | Enter/click runs the entry, increments its count, closes |
| Shortcuts | SUPER+H | parses `~/dotfiles/shortcuts.md`: `## ` → section, `\| keys \| action \|` → row; watched for changes; skips "Notes for Claude" | browse only; ←/→ or click switches section, typing searches all sections |
| Wallpaper | SUPER+W, SUPER+SHIFT+W | files in `~/Pictures/wallpapers`; gif/video stills from `~/.cache/wallpaper/thumbs` | `wallpaper.sh set <file>`, `wallpaper.sh effect <name>`; the backdrop previews the centred image before applying |
| Windows | SUPER+CTRL+S | `Hyprland.toplevels`: class, title, workspace; `ScreencopyView` of each toplevel | Enter focuses the window (switches workspace) |
| Power | CTRL+ALT+P | none | Lock `loginctl lock-session`, Sleep `systemctl suspend`, Log out `hyprctl dispatch 'hl.dsp.exit()'`, Reboot `systemctl reboot`, Power off `systemctl poweroff`. The last three need a second press within 3 s. Keys 1–5 |
| HUD | hold SUPER+SHIFT+P | `$XDG_RUNTIME_DIR/hud.json` written by `panel.py` every minute (and on start) | show while held, hide on release; auto-hide if no repeated `show` arrives within 600 ms |

Shared behaviour: Esc or a click outside closes; arrows + Enter everywhere;
hover and keyboard selection are the same highlight.

### HUD daemon change

`hypr/.config/hypr/panel/panel.py` keeps computing the schedule and firing
alerts, but stops creating GTK windows. It writes the schedule dict (the same
data `content.py` renders today) as JSON, atomically (write temp + rename).
`content.py`, `panel.css` and the GTK/layer-shell setup are removed once the QML
HUD renders the same content. The user's uncommitted edits to `panel.py` and the
untracked `patch_panel.py` are read first and preserved.

## Integration

- `startup.lua`: add `"qs -c glass"` after `bar.sh boot`.
- New `hypr/scripts/glass.sh <toggle|show|hide> <panel> [arg]`: calls
  `qs -c glass ipc call glass …`. If the glass shell is not running, `launcher`
  → `rofi -show drun`, `windows` → `rofi -show window`, others → notification.
- `keybinds.lua`: SUPER+D, SUPER+H, SUPER+W, SUPER+SHIFT+W, SUPER+CTRL+S, new
  CTRL+ALT+P → `glass.sh`. `panel.lua`: SUPER+SHIFT+P → `glass.sh show hud` (repeating) /
  `glass.sh hide hud` (release).
- `windowrules.lua`: layer rules for namespace `glass`: `no_anim = true`,
  no compositor blur.
- `wallpaper.sh`: add `set <file>` and `effect <name>`; remove `select` and
  `effects` rofi menus. Delete `rofi/config-wallpaper*.rasi`,
  `rofi/config-keybinds.rasi`, `local/bin/shortcut-viewer`. rofi stays installed
  as the fallback.
- Docs: README "Changing things" rows (add a panel; glass strength/speed);
  `shortcuts.md` adds CTRL+ALT+P and updates panel descriptions.

## Error handling

- `palette.json` missing/invalid → built-in sea-blue default, one warning.
- Unparseable `shortcuts.md` rows skipped; footer shows "N lines skipped".
- `hud.json` missing, invalid, or older than 2 minutes → "prayer times unavailable".
- Toplevel capture fails → tile shows the app icon.
- `wallpaper.sh` failure → notification; panel stays open.
- Glass shell down → `glass.sh` fallbacks above.

## Testing

- `glass/lib/*.js` (shortcuts parser, fuzzy match/score, launch-count sort,
  HUD staleness) covered by `qmltestrunner` tests in `glass/tests/`.
- Python: unit test for the `hud.json` writer; the existing 63 panel tests keep passing
  (tests for removed GTK-only code are removed with it).
- Shader: recompile `water.frag` with `/usr/lib/qt6/bin/qsb`; compile failure fails the step.
- Live, per panel: opens on the focused monitor of each screen; keyboard-only
  use; Esc and click-outside; swap between panels; island look unchanged except tint;
  HUD hold/release including fast taps.
