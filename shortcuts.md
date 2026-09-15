# Mahmood's Shortcut Guide

Living reference for every keybinding + workflow shortcut in this setup.
Claude auto-updates this file — if you learn/change/forget one, tell Claude.

Legend: `SUPER` = mainMod (Windows key).

---

## Hyprland — Session

| Keys | Action |
|---|---|
| `CTRL + ALT + Delete` | Exit Hyprland |
| `CTRL + ALT + L` | Lock screen |
| `CTRL + ALT + P` | Powermenu (wlogout) |
| `SUPER + F` | tmux sessionizer — fuzzy-pick a project, jump to (or create) its tmux session |
| `SUPER + Q` | Close active window |
| `SUPER + SHIFT + Q` | Kill active process (force) |
| `SUPER + SHIFT + N` | Notification panel toggle |
| `SUPER + SHIFT + E` | Quick settings menu |
| `SUPER + H` | Shortcut viewer — fuzzy-search this file via rofi, Enter for detail popup |
| `SUPER + SHIFT + K` | Search keybinds (rofi) |

## Hyprland — Windows

| Keys | Action |
|---|---|
| `SUPER + ←/→/↑/↓` | Focus window in direction |
| `SUPER + CTRL + ←/→/↑/↓` | Move window in direction |
| `SUPER + ALT + ←/→/↑/↓` | Swap window with neighbor |
| `SUPER + SHIFT + ←/→/↑/↓` | Resize by 50px |
| `SUPER + SPACE` | Toggle float |
| `SUPER + ALT + SPACE` | Float all windows on workspace |
| `SUPER + SHIFT + F` | Fullscreen |
| `SUPER + CTRL + F` | Maximize |
| `SUPER + CTRL + O` | Toggle active window opacity |
| `SUPER + G` | Toggle group |
| `SUPER + CTRL + Tab` | Cycle active in group |
| `ALT + Tab` | Cycle next window (brings floats to top) |
| `SUPER + drag LMB` | Move window with mouse |
| `SUPER + drag RMB` | Resize window with mouse |

## Hyprland — Workspaces

| Keys | Action |
|---|---|
| `SUPER + 1..0` | Go to workspace 1..10 |
| `SUPER + SHIFT + 1..0` | Move window to workspace 1..10 |
| `SUPER + CTRL + 1..0` | Move window to workspace silently |
| `SUPER + Tab` | Next workspace |
| `SUPER + SHIFT + Tab` | Previous workspace |
| `SUPER + . / ,` | Next / prev workspace |
| `SUPER + scroll` | Next / prev workspace |
| `SUPER + SHIFT + [ / ]` | Move window to prev / next workspace |
| `SUPER + CTRL + [ / ]` | Move window prev/next silently |
| `SUPER + U` | Toggle special workspace |
| `SUPER + SHIFT + U` | Move window to special workspace |
| `SUPER + CTRL + F9..F12` | Move workspace to left/right/up/down monitor |

## Hyprland — Layouts

| Keys | Action |
|---|---|
| `SUPER + I` | Add master |
| `SUPER + CTRL + D` | Remove master |
| `SUPER + CTRL + Return` | Swap window with master |
| `SUPER + SHIFT + I` | Toggle split (dwindle) |
| `SUPER + P` | Toggle pseudo (dwindle) |
| `SUPER + M` | Set split ratio to 0.3 |
| `SUPER + ALT + L` | Toggle master/dwindle layout |

## Hyprland — Launchers

| Keys | Action |
|---|---|
| `SUPER + Return` | Open terminal |
| `SUPER + SHIFT + Return` | Floating terminal (centered) |
| `SUPER + D` | App launcher (rofi drun) |
| `SUPER + E` | File manager |
| `SUPER + B` | Default browser |
| `SUPER + A` | OpenClaw TUI |
| `SUPER + ALT + A` | Desktop overview |
| `SUPER + S` | Web search (rofi) |
| `SUPER + CTRL + S` | Window switcher (rofi) |

## Hyprland — Apps (Custom)

| Keys | Action |
|---|---|
| `SUPER + L` | Launch **dojo** (algo practice) on ws7 fullscreen |
| `SUPER + T` | Launch **taskvim** on ws8 fullscreen |
| `SUPER + SHIFT + P` (hold) | Show **HUD panel** (prayer times overlay); release to hide |
| `SUPER + ALT + V` | Clipboard manager (cliphist via rofi) |
| `SUPER + ALT + E` | Emoji picker |
| `SUPER + ALT + C` | Calculator (rofi) |
| `SUPER + ALT + R` | Refresh bar/menus |

## Hyprland — Screenshots

| Keys | Action |
|---|---|
| `SUPER + Print` | Screenshot now |
| `SUPER + SHIFT + Print` | Screenshot area |
| `SUPER + CTRL + Print` | Screenshot in 5s |
| `SUPER + CTRL + SHIFT + Print` | Screenshot in 10s |
| `ALT + Print` | Screenshot active window |
| `SUPER + SHIFT + S` | Screenshot → swappy (annotate) |

## Hyprland — Look & Feel

| Keys | Action |
|---|---|
| `SUPER + W` | Wallpaper selector |
| `SUPER + SHIFT + W` | Wallpaper effects |
| `CTRL + ALT + W` | Random wallpaper |
| `SUPER + N` | Toggle night light (hyprsunset) |
| `SUPER + ALT + O` | Toggle blur |
| `SUPER + SHIFT + A` | Animations menu |
| `SUPER + SHIFT + O` | Change zsh theme (rofi) |
| `SUPER + CTRL + R` | Rofi theme selector |
| `SUPER + CTRL + SHIFT + R` | Rofi theme selector (modified) |
| `SUPER + SHIFT + G` | Toggle game mode |

## Hyprland — Waybar

| Keys | Action |
|---|---|
| `SUPER + CTRL + ALT + B` | Toggle waybar on/off |
| `SUPER + CTRL + B` | Waybar styles menu |
| `SUPER + ALT + B` | Waybar layout menu |

## Hyprland — Zoom / Magnifier

| Keys | Action |
|---|---|
| `SUPER + ALT + scroll up` | Zoom in (2×) |
| `SUPER + ALT + scroll down` | Zoom out (÷2) |

## Hyprland — Hardware / Media

| Keys | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioNext / Prev` | Next / prev track |
| `XF86AudioStop` | Stop |
| `XF86Sleep` | Suspend |
| `XF86Rfkill` | Airplane mode |
| `ALT_L + SHIFT_L` | Switch keyboard layout (global) |
| `SHIFT_L + ALT_L` | Switch keyboard layout (per-window) |

## Hyprland — Music (extras)

| Keys | Action |
|---|---|
| `SUPER + SHIFT + M` | Online music (rofi beats) |

---

## Terminal — zsh + fzf

Shortcuts inside the terminal (zsh + fzf integration loaded in `.zshrc`).

| Keys | Action |
|---|---|
| `CTRL + R` | **fzf** history search (fuzzy) |
| `CTRL + T` | **fzf** file picker, inserts path at cursor |
| `CTRL + F` | **fzf** cd — fuzzy-pick directory to cd into |
| `**<TAB>` | fzf completion trigger (e.g. `nvim **<TAB>`) |

### Inside any fzf picker

Two modes toggled by **Tab**. The prompt changes: `> ` = list mode, `preview> ` = preview-scroll mode.

| Keys | Action |
|---|---|
| `TAB` | Toggle mode: list-nav ⇄ preview-scroll |
| `CTRL + J` | Down (list) — or scroll preview down (in preview mode) |
| `CTRL + K` | Up (list) — or scroll preview up (in preview mode) |
| `↑ / ↓` | Always list up/down (unaffected by mode) |
| `CTRL + A` | Toggle multi-select mark on current line |
| `ENTER` | Confirm selection(s) |
| `ESC` / `CTRL + C` | Cancel |

### grep / ripgrep quick reference

| Cmd | Meaning |
|---|---|
| `grep PATTERN FILE` | Match pattern in file |
| `cmd \| grep PATTERN` | Filter output of cmd |
| `grep -rn PATTERN DIR` | Recursive, with line numbers |
| `grep -rni PATTERN DIR` | + case-insensitive |
| `grep -rnw PATTERN DIR` | + whole word only |
| `grep -rl PATTERN DIR` | Just filenames that match |
| `grep -v PATTERN FILE` | Invert — lines that DON'T match |
| `grep -E "a\|b" FILE` | Extended regex (OR, `()`, `+`, `?`) |
| `rg PATTERN [DIR]` | ripgrep — recursive by default, respects `.gitignore` |

### Regex mini-cheatsheet

| Pattern | Means |
|---|---|
| `.` | Any single char |
| `.*` | Any run of chars |
| `^foo` | Line starts with `foo` |
| `foo$` | Line ends with `foo` |
| `a\|b` | `a` OR `b` (needs `-E`) |

Always **single-quote** patterns so the shell doesn't eat special chars.

### Custom shell functions

| Cmd | Action |
|---|---|
| `fnv [DIR]` | Fuzzy-search every line in every file under DIR (default `.`), pick one, open nvim on that exact line. Combo: `rg` + `fzf` + `nvim +LINE`. |

### forgit — fuzzy git (from `forgit-git` AUR, sourced in `.zshrc`)

Run any of these inside a git repo:

| Cmd | Action |
|---|---|
| `ga` | Fuzzy **a**dd — pick files to stage with live diff preview |
| `glo` | Git **l**og browser — commits list + diff preview; Enter to show, Ctrl-Y to copy hash |
| `gd` | Fuzzy git **d**iff — pick file, see its diff |
| `gcf` | Git **c**heckout **f**ile — discard changes on selected files |
| `gcb` | Git **c**heckout **b**ranch — fuzzy switch branch |
| `gss` | Git **s**tash **s**how — browse stashes with preview |
| `gclean` | Fuzzy-pick untracked files to nuke |
| `grh` | Git **r**eset **H**EAD — unstage files |

### fzf workflow snippets

```sh
# Open file (or several) in nvim by fuzzy-finding it
nvim $(find . -type f | fzf)

# Copy a path to clipboard (Wayland)
find ~ -type f | fzf | wl-copy

# Fuzzy-pick from clipboard history
cliphist list | fzf | cliphist decode | wl-copy

# Bulk delete .log files, pick which
find . -name '*.log' | fzf | xargs rm

# Kill a process interactively
ps aux | fzf | awk '{print $2}' | xargs kill
```

---

## tmux

Prefix is `Ctrl+a` (rebound from default `Ctrl+b`). All shortcuts below mean: press `Ctrl+a`, release, then the key.

### Sessions

| Keys | Action |
|---|---|
| `tmux` | Start unnamed session |
| `tmux new -s <name>` | Start named session |
| `tmux ls` | List sessions |
| `tmux attach -t <name>` | Attach to session |
| `Ctrl+a d` | Detach (leaves session running) |
| `Ctrl+a s` | Session picker (jump between sessions) |
| `Ctrl+a $` | Rename current session |

### Windows (tabs)

| Keys | Action |
|---|---|
| `Ctrl+a c` | Create new window |
| `Ctrl+a n` / `p` | Next / previous window |
| `Ctrl+a 0..9` | Jump to window by number |
| `Ctrl+a ,` | Rename current window |
| `Ctrl+a &` | Kill current window (asks y/n) |

### Panes (splits)

| Keys | Action |
|---|---|
| `Ctrl+a %` | Split vertically (left / right) |
| `Ctrl+a "` | Split horizontally (top / bottom) |
| `Ctrl+a h/j/k/l` | Move to pane left/down/up/right (vim keys) |
| `Ctrl+a ←/↓/↑/→` | Move to pane by arrow |
| `Ctrl+a x` | Kill current pane (asks y/n) |
| `Ctrl+a z` | Zoom pane toggle (fullscreen one pane) |

### Copy mode (vim-style)

Enter copy mode with `Ctrl+a [`, then:

| Keys | Action |
|---|---|
| `h/j/k/l`, arrows, `PgUp`/`PgDn` | Move cursor |
| `w` / `b` | Word forward / back |
| `0` / `$` | Line start / end |
| `?` `text` `Enter` | Search up (`/` for down); `n` = next |
| `v` | Start character selection |
| `V` | Start line selection |
| `y` | Yank to **system clipboard** (via `wl-copy`) and exit |
| `q` | Exit copy mode without copying |
| `Ctrl+a ]` | Paste tmux buffer |

Mouse drag → release also copies to system clipboard.

### Config

| Keys | Action |
|---|---|
| `tmux source-file ~/.tmux.conf` | Reload config live |

Plugins loaded via TPM: `tmux-resurrect` + `tmux-continuum` — sessions auto-save every 2 min and restore on tmux start.

---

## Notes for Claude (auto-maintenance)

When Claude notices the user adding, removing, or asking about a shortcut in *any* session:
1. Read this file.
2. Add / update / remove the row.
3. Keep sections alphabetical within their category when possible, but keep grouping semantic (Session, Windows, Workspaces, etc).
4. Commit is the user's job (they use `~/dotfiles/update.sh`). Don't commit unless asked.
