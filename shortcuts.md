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
| `SUPER + SHIFT + B` | Cycle top bar: waybar → **Peek** glass bar → **Dynamic Island** |
| `SUPER` (hold) | Peek / Island modes: show the full glass bar while held |
| `SUPER + SHIFT` (hold) | Island mode over a fullscreen window: the only way to show the island |

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
| `Ctrl+a e` | Reopen the lens panel of Claude's edits (see below) |
| `Ctrl+a E` | Toggle the lens auto-popup for the project in the current pane (capture keeps running) |

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

### Session persistence

| Keys | Action |
|---|---|
| `Ctrl+a Ctrl+s` | Save session layout now (tmux-resurrect) |
| `Ctrl+a Ctrl+r` | Restore the last saved layout |

Plugins loaded via TPM: `tmux-resurrect` + `tmux-continuum` — sessions auto-save
every 2 min and restore on tmux start, so they survive a reboot.

Restored automatically: **pane scrollback**, `nvim`/`vim`, `ssh`, `btop`,
`lazygit`, `yazi`, `lazydocker`, and `claude` — Claude panes come back as
`claude --continue`, i.e. on the same conversation, not a blank one.
Snapshots live in `~/.local/share/tmux/resurrect/` (newest 20 kept).


## Neovim

Leader is `SPACE`. Config: `~/.config/nvim` — **every keybinding lives in
`lua/core/keymaps.lua`**, in numbered sections. Nothing else in the config sets
a key. Press `SPACE s k` in nvim for a searchable picker of every active map,
or just `SPACE` and wait for which-key.

### Neovim — General

| Keys | Action |
|---|---|
| `CTRL + S` | Save (works in insert + visual too) |
| `ESC` | Clear search highlight |
| `SPACE q q` | Quit all |
| `ALT + J / K` | Move line or selection down / up |
| `< / >` (visual) | Indent, keeping the selection |
| `CTRL + D / U` | Half page down / up, recentred |
| `n / N` | Next / prev search result, recentred |
| `p` (visual) | Paste over selection without clobbering the register |
| `SPACE y` / `SPACE Y` | Yank selection / line to system clipboard |
| `s` / `S` | Flash jump / Flash treesitter jump |
| `SPACE u i` | Inspect syntax highlight under cursor |

### Neovim — Windows, Buffers, Tabs

| Keys | Action |
|---|---|
| `CTRL + H/J/K/L` | Move to window left/down/up/right (works from a terminal too) |
| `CTRL + arrows` | Resize window |
| `SPACE -` / `SPACE \|` | Split below / right |
| `SPACE w d` | Close window |
| `SPACE w m` | Maximise window (toggle) |
| `SHIFT + H / L` | Previous / next buffer |
| `[b` / `]b` | Previous / next buffer |
| `SPACE b b` | Switch to the other buffer |
| `SPACE b d` / `SPACE b o` | Delete buffer / delete all other buffers |
| `SPACE b p` | Pin buffer in the bufferline |
| `SPACE TAB TAB` | New tab |
| `SPACE TAB d` / `[` / `]` | Close / prev / next tab |

### Neovim — Find & Search (telescope)

| Keys | Action |
|---|---|
| `SPACE SPACE` | Find files (project root) |
| `SPACE f f` / `SPACE f F` | Find files — root / cwd |
| `SPACE f g` | Live grep (root) |
| `SPACE f b` | Buffers |
| `SPACE f r` | Recent files |
| `SPACE f h` | Help tags |
| `SPACE f c` | Find a file in the nvim config |
| `SPACE /` or `SPACE s g` | Grep (root) |
| `SPACE s G` | Grep (cwd) |
| `SPACE s b` | Grep inside current buffer |
| `SPACE s w` | Grep the word under the cursor |
| `SPACE s k` | **Every keymap** — searchable |
| `SPACE s c` | Commands |
| `SPACE s d` | Workspace diagnostics |
| `SPACE s m` | Marks |
| `SPACE s R` | Resume last picker |
| `SPACE s s` / `SPACE s S` | Document / workspace symbols |
| `SPACE s h` | Highlight groups |
| `SPACE s t` | Todo comments |
| `SPACE s n` | Message history (noice) — full, scrollable, untruncated |
| `SPACE s N` | Errors only (noice) |

Inside a picker: `CTRL + J/K` move, `CTRL + Q` send to quickfix, `ESC` closes
(one press), `CTRL + U` clears the prompt.

### Neovim — File Explorer

| Keys | Action |
|---|---|
| `SPACE e` | Explorer at project root (snacks) |
| `SPACE E` | Explorer at cwd |
| `H` (in tree) | Toggle hidden / dotfiles |

### Neovim — Code & LSP

Buffer-local; these appear once a language server attaches.

| Keys | Action |
|---|---|
| `g d` / `g r` | Goto definition / references |
| `g I` / `g y` / `g D` | Implementation / type definition / declaration |
| `K` | Hover documentation |
| `g K` / `CTRL + K` (insert) | Signature help |
| `SPACE c a` | Code action |
| `SPACE c r` | Rename symbol |
| `SPACE c f` | Format buffer now |
| `SPACE c c` | Run code lens (when the server offers one) |
| `SPACE c R` | Rename the file |
| `SPACE c m` | Mason (install servers/formatters) |
| `SPACE c l` | LSP health check |
| `SPACE L` | Lazy (plugin manager) |

### Neovim — Diagnostics

| Keys | Action |
|---|---|
| `D` | Show the diagnostic under the cursor |
| `SPACE c d` | Same, as a float |
| `]d` / `[d` | Next / previous diagnostic |
| `]e` / `[e` | Next / previous **error** |
| `]w` / `[w` | Next / previous **warning** |
| `SPACE x x` / `SPACE x X` | Trouble — workspace / buffer diagnostics |
| `SPACE x s` | Trouble — symbols |
| `SPACE x l` / `SPACE x q` | Location list / quickfix list |
| `SPACE x t` | Todo comments |

### Neovim — Git

| Keys | Action |
|---|---|
| `SPACE g g` or `SPACE l g` | LazyGit |
| `SPACE g f` | LazyGit on the current file |
| `SPACE g c` / `SPACE g s` / `SPACE g B` | Commits / status / branches (telescope) |
| `SPACE g y` | Open current line on the git host in a browser |
| `]h` / `[h` | Next / previous hunk |
| `SPACE g h s` / `SPACE g h r` | Stage / reset hunk (works on a visual selection) |
| `SPACE g h S` / `SPACE g h R` | Stage / reset whole buffer |
| `SPACE g h p` | Preview hunk inline |
| `SPACE g h b` or `SPACE g b` | Blame line (full) |
| `SPACE g h d` | Diff this file |

### Neovim — Toggles (`SPACE u`)

| Keys | Action |
|---|---|
| `SPACE u f` | **Format on save** |
| `SPACE u s` / `SPACE u w` | Spelling / wrap |
| `SPACE u l` / `SPACE u L` | Line numbers / relative numbers |
| `SPACE u d` | Diagnostics |
| `SPACE u h` | Inlay hints |
| `SPACE u g` | Indent guides |
| `SPACE u c` | Conceal |
| `SPACE u T` | Treesitter highlight |
| `SPACE u D` | Dim inactive code |
| `SPACE u b` | Dark / light background |
| `SPACE u n` | Dismiss notifications |
| `SPACE u r` | Redraw / clear highlights |

### Neovim — Terminal

| Keys | Action |
|---|---|
| `CTRL + /` | Toggle floating terminal (also works from inside it) |
| `SPACE t f / t h / t v` | Terminal float / horizontal / vertical |
| `ESC ESC` | Leave terminal mode |

### Neovim — Run & Build

| Keys | Action |
|---|---|
| `SPACE r r` | Compile **and run** the current C/C++ file in a tmux window named `run` |
| `SPACE r b` | Compile only |
| `SPACE r p` | Run the current Python file in the `run` tmux window |

Compiles with `-Wall -Wextra -g`. Falls back to a split `:terminal` when not
inside tmux. (This was `SPACE c a r` before — it moved because it made every
`SPACE c a` code action wait 400ms.)

### Neovim — Debug (DAP)

| Keys | Action |
|---|---|
| `F5` | Start / continue |
| `F9` | Toggle breakpoint |
| `F10` / `F11` / `F12` | Step over / into / out |
| `SPACE d b` / `SPACE d B` | Toggle breakpoint / conditional breakpoint |
| `SPACE d c` | Continue |
| `SPACE d o` / `SPACE d i` / `SPACE d O` | Step over / into / out |
| `SPACE d u` | Toggle the debugger UI |
| `SPACE d e` | Evaluate expression |
| `SPACE d r` | Toggle REPL |
| `SPACE d t` | Terminate |

The UI opens and closes with the session automatically.

### Neovim — AI / Claude

| Keys | Action |
|---|---|
| `SPACE a c` | Toggle Claude |
| `SPACE a f` | Focus Claude |
| `SPACE a r` / `SPACE a C` | Resume / continue a session |
| `SPACE a s` (visual) | Send the selection to Claude |
| `SPACE a b` | Add the current buffer to Claude's context |

Copilot appears as a source in the completion menu (top-ranked), not as ghost
text you have to fight.

### Neovim — Completion (while the popup is open)

| Keys | Action |
|---|---|
| `CTRL + SPACE` | Open the completion menu |
| `TAB` / `SHIFT + TAB` | Next / previous item, or jump snippet placeholders |
| `CTRL + J / K` | Next / previous item |
| `ENTER` | Accept |
| `CTRL + E` | Dismiss |

### Neovim — Sessions & Scratch

| Keys | Action |
|---|---|
| `SPACE q s` / `SPACE q l` | Restore session for cwd / last session |
| `SPACE q d` | Stop saving the current session |
| `SPACE .` / `SPACE S` | Toggle scratch buffer / pick one |
| `SPACE z` / `SPACE Z` | Zen mode / zoom |
| `]]` / `[[` | Next / previous reference to the word under the cursor |

### Neovim — Textobjects

Only meaningful after an operator (`d`, `c`, `y`, `v`):

| Keys | Selects |
|---|---|
| `af` / `if` | A function / its body |
| `ac` / `ic` | A class / its body |
| `aa` / `ia` | An argument / its contents |
| `]f` / `[f` | Jump to next / previous function |

---

## lens — Claude change panel

Pops up in a tmux popup when Claude finishes a turn that changed files (a turn that only
answered a question leaves it closed; `Ctrl+a E` turns the auto-popup off and on for the project you're in, leaving other projects alone); shows every add/remove
with the prompt that caused it. The popup holds the keyboard, so it scrolls straight away — no
pane to switch to first. `Ctrl+a e` reopens it after you close it.
Opens ready to search — type to filter by file name. The diff uses the same tokyonight-moon
colours as nvim. Unread edits carry a `●` and stay bright; landing on one reads it. Read state is kept per
session, so closing and reopening the popup doesn't mark everything new again.
Session-only: the log is swept 24 hours after the last change.

| Keys | Action |
|---|---|
| `j` / `k` | Move down / up |
| `/` | Filter the list by file name as you type (`Enter` keeps it, `Esc` clears it) |
| `CTRL + j` / `CTRL + k` | Move through the results while the filter prompt is open |
| `CTRL + e` / `CTRL + y` | Scroll the diff one line, from either pane |
| `CTRL + f` / `CTRL + b` | Scroll the diff one page, from either pane |
| `CTRL + d` / `CTRL + u` | Half page down / up |
| `gg` / `G` | First / last entry |
| `n` / `N` | Next / previous hunk |
| `J` / `K` | Next / previous file |
| `t` | Toggle view (timeline ⇄ grouped by file) |
| `+` / `-` | More / less surrounding context |
| `Tab` | Move focus between the list and the diff (the diff gets its own cursor) |
| `●` | Marks an edit you haven't looked at yet (it dims once you land on it) |
| `?` | Help |
| `q` | Close the popup (the log stays; `Ctrl+a e` reopens it) |

---

## Notes for Claude (auto-maintenance)

When Claude notices the user adding, removing, or asking about a shortcut in *any* session:
1. Read this file.
2. Add / update / remove the row.
3. Keep sections alphabetical within their category when possible, but keep grouping semantic (Session, Windows, Workspaces, etc).
4. Commit is the user's job (they use `~/dotfiles/update.sh`). Don't commit unless asked.
