# Island notifications hub — design

Date: 2026-09-27

## Goal

Make the Dynamic Island the notification daemon and give it a hub: click the
island and it grows into a minimal, clean list of notifications; click a
notification and it opens in full. swaync is removed from the setup.

## Decisions (made with the user)

| Question | Choice |
|---|---|
| Who owns notifications | The island: Quickshell's `NotificationServer` replaces swaync |
| Other bar modes (waybar / peek) | Don't matter: no notification daemon there |
| Where the hub lives | An island panel mode (`notifs`), like the Wi-Fi / Bluetooth panels |
| How it opens | Click the island body (info view, SUPER-held view, resting bar); SUPER+SHIFT+N toggles it |
| Clicking a notification popup | Opens the hub on that notification's full view (no longer dismisses) |
| Extras in v1 | Group by app · history survives restarts · SUPER+SHIFT+N opens the hub |
| Not in v1 | Do Not Disturb, inline replies, detaching the hub into a floating panel |

## Units

### `island/lib/notifs.js` — pure logic (tested)

No QML types, no I/O. Entries are plain objects:

```
{ key, app, appIcon, summary, body, urgency, time, image, live }
```

`key` is a string unique for the history's lifetime (`"<time>-<id>"`); `live`
is true while a live `Notification` object backs the entry (never saved).

- `groups(entries)` → `[{ app, appIcon, count, latest, items }]`, newest
  group first, items newest first. Grouping key is the app name
  (empty name → `"Unknown"`).
- `add(entries, entry, cap)` → new list with `entry` first, trimmed to `cap`
  (100) by dropping the oldest.
- `remove(entries, key)`, `removeApp(entries, app)`.
- `serialize(entries)` → JSON string without `live` or `image` (the image is
  a live `image://` URL that dies with the notification).
- `deserialize(text)` → entries (invalid / missing file → `[]`; entries
  missing `key` or `time` are dropped); every entry comes back `live: false`.
- `ago(time, now)` → `"now"`, `"5m"`, `"3h"`, `"2d"`.
- `isOsd(hints)`: true for `x-canonical-private-synchronous` or a `value`
  hint (volume/brightness level popups; the island shows those natively).

### `island/Notifs.qml` — the daemon + history

Instantiated once in `shell.qml`, exposed as `root.notifs`.

- `NotificationServer` advertising body, body markup off, actions, images,
  `keepOnReload: true`.
- On `notification`:
  - OSD → ignored (not tracked, so it's dropped).
  - otherwise `tracked = true`, a new entry is added, it's remembered in a
    `key → Notification` map, and the `posted(entry)` signal fires (the popup).
  - `transient` notifications popup but are not added to the history; they
    are dismissed after their popup.
- A live notification's `closed(reason)`:
  - closed by the app (`CloseRequested`) → the entry is removed from the hub.
  - expired / dismissed by us → nothing extra (we already handled it).
- Popups time out on the island only; the notification stays tracked in the
  hub. We never call `expire()` on popup timeout.
- API: `entries` (list), `groups` (derived), `count`, `dismiss(key)`,
  `dismissApp(app)`, `clearAll()`, `actions(key)` → live actions or `[]`,
  `invoke(key, identifier)` (invokes, then removes the entry unless the
  notification is `resident`). Dismissing a live entry calls `dismiss()` on it.
- Persistence: `FileView` on `$XDG_STATE_HOME/island/notifications.json`
  (default `~/.local/state/island/…`), `atomicWrites: true`. Loaded at
  startup; written (debounced ~500 ms) after every change.

### `island/NotifPanel.qml` — the hub UI

Drawn inside the island capsule for `viewMode === "notifs"`, following the
WifiPanel/BtPanel look (same glass, text styles, Theme colors, radius 26).
Two views, cross-faded:

- **List**
  - Header: "Notifications" + "Clear all" (hidden when empty).
  - One row per app group: app icon, app name, newest summary (one line,
    elided), count badge when > 1, relative time (`ago`).
  - Hover shows a ✕ on the row: dismisses the whole group.
  - Click a group of 1 → opens that notification; a group of more → expands
    in place to its notifications (summary + one line of body + time,
    each with its own ✕); clicking one opens it.
  - Empty state: a bell glyph and "No notifications".
  - Scrolls when it outgrows the max height.
- **Full view**
  - Back arrow, app icon + name, time.
  - Summary (wrapped), full body (wrapped, scrolls if long).
  - Image when live and present.
  - Action buttons (live entries only). If there's a `default` action, an
    "Open" button invokes it. Restored entries show no buttons.
  - Dismiss button: removes it and returns to the list.

Size: width ~420 px; height follows content, capped (~480 px), so the island
morphs to it like the other panels.

### Changes to existing files

- `island/shell.qml`
  - Replace the `notifwatch` Process with `Notifs { id: notifs }`;
    `onPosted` sets `root.notif` and pulses the popup as today.
  - New state: `hubKey` (notification to open in full, `""` = list),
    `hubKeyboard` (hub opened from the keyboard).
  - `openHub(key)` → `panel = "notifs"`, `hubKey = key`.
  - `GlobalShortcut { name: "notifs" }` toggles the hub (keyboard).
  - The `close` shortcut also closes the hub.
  - IPC: `hub <key|"">` opens the hub (list or one entry), `hubclose`
    closes it. The existing `notify` test call stays as-is (popup only,
    not added to the history); real tests go through `notify-send`.
- `island/DynIsland.qml`
  - `notifs` joins `wifi`/`bt` as a panel mode (size, radius 26, fullscreen
    rules, hover close, idle close).
  - Tap routing by mode at press time:
    `info` / `full` → open the hub · `notif` → open the hub on that
    notification · `level` / `toast` / `ws` → dismiss (as today). Taps on
    chips keep their own handling.
  - A small count (e.g. a bell + number) in the info and SUPER-held views
    when the hub is not empty.
  - Keyboard: while the hub is open from the keyboard, the island takes
    `Exclusive` keyboard focus; Esc / Ctrl+[ close it (common/keys.js), and
    the 4 s idle close doesn't apply. Opened by click, it behaves like the
    other panels (closes when the pointer leaves).
- `island/notifwatch.py` — deleted.
- `hypr/.config/hypr/lua/keybinds.lua` — SUPER+SHIFT+N → `island:notifs`;
  SUPER+Q also checks the `island` layer (keyboard-held hub) and dispatches
  `island:close`.
- `hypr/.config/hypr/lua/startup.lua` — drop `swaync`.
- `hypr/.config/hypr/scripts/bar.sh` — drop the swaync DND functions and the
  `notifwatch.py` pkill.
- `hypr/.config/hypr/scripts/airplane.sh` — drop the swaync mention.
- `waybar/.config/waybar/ModulesCustom`, `ModulesGroups` — drop
  `custom/swaync`.
- `local/.local/bin/palette-apply` — drop `swaync-client --reload-css`.
- `theming/.config/palette/templates/colors.css` — comment no longer names
  swaync.
- `notify/` stow package — deleted (unstow first); README row removed.
- The user uninstalls swaync (`sudo pacman -Rns swaync`): its D-Bus service
  file would otherwise auto-start it whenever nothing owns
  `org.freedesktop.Notifications`, e.g. at login before the island is up.

## Data flow

```
app ─Notify─▶ NotificationServer ─▶ Notifs (entry + live map + posted)
                                        │            │
                              save JSON ◀┘            ▼
                                             shell.qml: root.notif + pulse("notif")
                                                     │ click popup
                                                     ▼
            click island / SUPER+SHIFT+N ──▶ panel = "notifs", hubKey
                                                     ▼
                                             NotifPanel (list ⇄ full)
                                    dismiss / clear / invoke ──▶ Notifs
```

## Error handling

- History file missing or corrupt → start empty, overwrite on next change.
- A restored entry's app can't be reached → it has no actions; only dismiss.
- Icon lookup fails → fall back to a generic bell glyph (as the popup does).
- If the island isn't running, notifications are not shown or kept (accepted:
  only island mode matters).

## Testing

- `island/tests/tst_notifs.qml` (qmltestrunner, like `glass/tests`):
  grouping and order, cap at 100, remove / removeApp, serialize drops `live`
  and `image`, deserialize of garbage / partial entries, `ago`, `isOsd`.
- Live checks with `notify-send`: plain, long body, `-A` actions (and
  `default`), `-i` image, several from one app, `-u critical`, `-e`
  transient, a volume OSD hint; restart the island (PRIME=0, see memory) and
  confirm the history returns without actions; SUPER+SHIFT+N, Esc, SUPER+Q;
  click paths from info view, SUPER-held view and a popup.
