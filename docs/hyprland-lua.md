# Hyprland's Lua config, and the trap in `hyprctl dispatch`

Read this before writing or editing any script that calls `hyprctl`. It
documents one behaviour that breaks scripts silently and is not obvious from
the error output.

Verified against **Hyprland 0.56.2** with a Lua config.

---

## Background

This config was migrated from the legacy `.conf` format to Lua, which Hyprland
0.57 makes mandatory. `~/.config/hypr/hyprland.lua` is the entry point and
`require()`s modules from `lua/`. (The pre-Lua `.conf` originals are in git
history if you ever need them.)

The Lua parser is stricter than the old one. It enforces ranges the `.conf`
parser silently accepted — animation speed must be ≤ 100, bezier control points
must fall in `[-1.0, 2.0]`.

**Always validate before reloading:**

```sh
Hyprland --verify-config    # parses without touching the running session
hyprctl reload
```

---

## The trap: `hyprctl dispatch` takes a Lua expression

On this build, whatever you pass to `hyprctl dispatch` is wrapped as:

```lua
return hl.dispatch( <your argument> )
```

and evaluated as Lua. Legacy dispatch syntax is therefore a **syntax error**,
not a command:

```console
$ hyprctl dispatch workspace 8
error: [string "return hl.dispatch(workspace 8)"]:1: ')' expected near '8'
```

### Why this bites

`hyprctl` exits non-zero here, but almost no script checks its exit status. A
script full of legacy dispatches runs to completion, prints nothing, and does
nothing. Every JaKooLit script that used the old syntax was silently dead from
the moment of migration until it was found and repaired.

If a keybinding "does nothing", this is the first thing to check.

### Translation

| Legacy | Lua |
|---|---|
| `hyprctl dispatch workspace 8` | `hyprctl dispatch 'hl.dsp.focus({ workspace = 8 })'` |
| `hyprctl dispatch exec "app"` | `hyprctl dispatch 'hl.dsp.exec_cmd("app")'` |
| `hyprctl dispatch exec "[workspace 7] app"` | `hl.exec_cmd("app", { workspace = "7" })` — rules are a table now, not a string prefix |
| `hyprctl dispatch exit` | `hyprctl dispatch 'hl.dsp.exit()'` |
| `hyprctl dispatch fullscreen 1` | `hyprctl dispatch 'hl.dsp.window.fullscreen(1)'` |
| `hyprctl dispatch movetoworkspacesilent 5` | `hyprctl dispatch 'hl.dsp.workspace.move({ workspace = 5, silent = true })'` |

Quoting matters: the argument must reach `hyprctl` as one shell word, so wrap it
in single quotes.

---

## Two further traps

### `hl.dsp.window.*` only ever acts on the **active** window

Passing `address = "0x…"` is accepted and **silently ignored**. The dispatch
returns `ok` and nothing happens. `hl.get_window(…)` is read-only and cannot
help. The only way to target a specific window is to focus it first:

```sh
hyprctl dispatch 'hl.dsp.focus({ window = "address:0x55f1a2b3c4" })'
hyprctl dispatch 'hl.dsp.window.fullscreen(1)'
```

This is why the TUI launchers in `hypr/scripts/` avoid
address-based dispatch entirely. They set a unique `--class` and let **window
rules** do the placement — declarative, race-free, and applied before the
window maps:

```lua
hl.window_rule({ match = { class = "^(taskvim)$" }, workspace = "8" })
hl.window_rule({ match = { class = "^(taskvim)$" }, fullscreen = true })
```

### Window rules spell "silent" inside the workspace string

```lua
hl.window_rule({ ..., workspace = "8 silent" })   -- correct
hl.window_rule({ ..., workspace = "8", silent = true })   -- WRONG, ignored
```

---

## Discovering the API

`/usr/share/hypr/stubs/hl.meta.lua` (67 KB) documents `hl.*` functions, events
and config keys. It does **not** document the option tables accepted by
`hl.dsp.*` — those need runtime probing.

`hyprctl dispatch` only accepts an expression, so a bare `do … end` block fails.
Wrap the probe in an immediately-invoked function:

```sh
hyprctl dispatch '(function()
  local t = {}
  for k in pairs(hl.dsp) do t[#t+1] = k end
  table.sort(t)
  return hl.dsp.exec_cmd("notify-send \"" .. table.concat(t, " ") .. "\"")
end)()'
```

Current output on 0.56.2:

```
hl.dsp:            cursor, dpms, event, exec_cmd, exec_raw, exit, focus,
                   force_idle, force_renderer_reload, global, group, layout,
                   no_op, pass, release_input_capture, send_key_state,
                   send_shortcut, submap, window, workspace

hl.dsp.window:     alter_zorder, bring_to_top, center, clear_tags, close,
                   cycle_next, deny_from_group, drag, float, fullscreen,
                   fullscreen_state, kill, move, pin, pseudo, resize, set_prop,
                   signal, swap, tag, toggle_swallow

hl.dsp.workspace:  change_id, move, rename, swap_monitors, toggle_special

hl.dsp.group:      active, lock, lock_active, move_window, next, prev, toggle
```

---

## Tools that write into the config directory

Two tools rewrite files under `~/.config/hypr`. Because that path is a
directory symlink into this repo, their writes land in the repo — which is why
the generated files are gitignored.

| Tool | Writes | Notes |
|---|---|---|
| `palette-apply` | `lua/colors.lua` | Rendered from `~/.config/palette/templates/hypr-colors.lua` using `palette.conf` |
| nwg-displays | `monitors.conf`, `workspaces.conf` | Can only emit `.conf`. **Use the wrapper** `scripts/nwg-displays.sh`, which then runs `scripts/nwg-displays-to-lua.py` to convert. Running `nwg-displays` directly leaves the Lua stale |

`hyprctl getoption` still works for reading live values, but **`hyprctl keyword`
is rejected** by the Lua parser ("keyword can't work with non-legacy parsers").
Set options at runtime through `hyprctl eval` instead:

```sh
hyprctl eval 'hl.config({ cursor = { zoom_factor = 2 } })'
hyprctl eval 'hl.device({ name = "etps/2-elantech-touchpad", enabled = false })'
```

`hl.exec_cmd(cmd, { workspace = "9 silent" })` places a launched app on a
workspace (used by the autostart list in `lua/startup.lua`).

---

## Adding a new TUI launcher

The established pattern, as used by `SUPER+T`, `SUPER+A` and `SUPER+L`:

1. **Launcher script** — focus the workspace, then launch with a unique class
   only if no instance exists:

   ```sh
   #!/bin/sh
   CLASS=myapp
   hyprctl dispatch 'hl.dsp.focus({ workspace = 6 })'
   if ! hyprctl clients -j | grep -q "\"class\": \"$CLASS\""; then
       setsid -f kitty --class "$CLASS" myapp >/dev/null 2>&1
   fi
   ```

2. **Window rules** in `lua/windowrules.lua`:

   ```lua
   hl.window_rule({ match = { class = "^(myapp)$" }, workspace = "6" })
   hl.window_rule({ match = { class = "^(myapp)$" }, fullscreen = true })
   ```

3. **Bind** in `lua/keybinds.lua`:

   ```lua
   hl.bind(mod .. " + M", sh(user .. "/myapp-launch.sh"),
           { description = "myapp (ws 6, fullscreen)" })
   ```

Then `Hyprland --verify-config && hyprctl reload`.

A unique class matters: matching on the terminal's default class (`kitty`) plus
a title is fragile, because TUIs rewrite their titles at runtime and the
already-running check then fails, spawning duplicates.
