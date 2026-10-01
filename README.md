# dotfiles

A complete Hyprland desktop, reproducible on a new machine with two commands.

```sh
git clone <this-repo> ~/dotfiles
~/dotfiles/install.sh
```

Everything in `~/.config` that matters is here: the compositor, the bar, the
launcher, the terminals, the editor, the theming stack, and the shell. Nothing
personal is: no names, no emails, no tokens, no browser profiles, no history.
[What is NOT in here](#what-is-not-in-here) explains every exclusion.

---

## Table of contents

- [How it works](#how-it-works)
- [What is in here](#what-is-in-here)
- [What is NOT in here](#what-is-not-in-here)
- [Installing on a new machine](#installing-on-a-new-machine)
- [Daily use](#daily-use)
- [The Hyprland config in detail](#the-hyprland-config-in-detail)
- [Keybindings worth knowing](#keybindings-worth-knowing)
- [Troubleshooting](#troubleshooting)
- [Design decisions](#design-decisions)

---

## How it works

The repo is a set of **GNU stow packages**. Each top-level directory mirrors the
layout of `$HOME`, and `stow` creates symlinks from `$HOME` into the repo:

```
~/dotfiles/hypr/.config/hypr/…      ← the real files live here
~/.config/hypr  ->  ../dotfiles/hypr/.config/hypr
```

The consequence that matters day to day: **you edit configs exactly as you
always did**, at `~/.config/hypr/lua/keybinds.lua`, and the change is already in
the repo. `git status` sees it immediately. There is no separate "sync" step to
forget.

```
   edit ~/.config/hypr/…        (a symlink into the repo)
              │
              ▼
   git status shows it          (no copying, no sync script)
              │
              ▼
   ./update.sh -m "message"     (commits, refreshes package lists,
              │                  scans for leaked secrets)
              ▼
   git push                     (other machines: git pull && ./install.sh)
```

Why stow rather than a bare repo or chezmoi: it is one already-installed
binary, the symlinks are inspectable with `ls -l`, and `uninstall.sh` puts
everything back. No templating language, no daemon, no state directory.

---

## What is in here

| Package | Deploys to | Contents |
|---|---|---|
| `hypr` | `~/.config/hypr` | Compositor config (Lua), a dozen small scripts, hyprlock, hypridle, HUD panel |
| `nvim` | `~/.config/nvim` | Neovim, kickstart-derived, with `lazy-lock.json` pinning plugin versions |
| `waybar` | `~/.config/waybar` | Fallback status bar (the Dynamic Island is the main one) |
| `rofi` | `~/.config/rofi` | Fallback launcher (used only if the glass shell isn't running) |
| `widgets` | `~/.config/quickshell` | Dynamic Island, Peek bar, and the **glass panels** (launcher, shortcuts, wallpaper, windows, power, HUD) sharing one water-glass kit in `common/` |
| `terminals` | `~/.config/{kitty,alacritty,ghostty,wezterm}` | All four terminals |
| `shell` | `~/.zshrc`, `~/.tmux.conf`, `~/.tmux` | Zsh (custom prompt, lazy-loaded nvm, plugins) and tmux |
| `cli` | `~/.config/…` | btop, cava, fastfetch, glow, lazygit, mpv, swappy, qutebrowser, matplotlib, procps, yay, psd, argos-translate, `starship.toml` |
| `theming` | `~/.config/…`, `~/.themes` | **The color palette** (`~/.config/palette`), GTK 2/3, Kvantum, qt5ct, qt6ct, GTK themes |
| `desktop` | `~/.config/…` | Thunar, xfce4, xdg-desktop-portal, autostart, menus, wireplumber, systemd user units, mimeapps, user-dirs, dolphin/kwallet/pavucontrol rc files |
| `gitcfg` | `~/.config/git` | Global gitignore (no identity — see `templates/gitconfig.example`) |
| `claude` | *copied, not linked* | Claude Code `settings.json` |

Plus:

- `packages/` — every explicitly-installed pacman and AUR package ([details](packages/README.md))
- `templates/` — the machine-specific and secret files, with placeholders
- `docs/` — deeper notes ([hyprland-lua.md](docs/hyprland-lua.md), [adding-a-package.md](docs/adding-a-package.md))
- `install.sh` / `update.sh` / `uninstall.sh`

---

## What is NOT in here

Every exclusion is deliberate. Grouped by why.

### Credentials — would be a live leak

| Excluded | Reason |
|---|---|
| `~/.git-credentials` | Plaintext git passwords |
| `~/.gitconfig` | Your name and email. Ship `templates/gitconfig.example` instead |
| `~/.config/gh`, `~/.config/github-copilot` | OAuth tokens |
| `~/.config/exercism` | API token |
| `~/.config/zoomus.conf` | Stored account credentials |
| `~/.config/secrets.env` | The OpenClaw token. Created from a template by `install.sh`, `chmod 600`, gitignored |
| `~/.ssh`, `~/.gnupg` | Private keys. Move these by hand, over a channel you trust |

A second net behind `.gitignore`: `.githooks/secret-scan` runs on every commit
and push (wired by `install.sh` via `core.hooksPath`) and blocks token shapes,
hardcoded passwords and files like keys or `.env`. Audit the whole history
with `.githooks/secret-scan all`.

### Personal data — not config

`~/.config/zen` (84 MB Firefox-derived browser profile: history, cookies,
sessions), `~/.claude` minus `settings.json` (373 MB of conversation history
and caches), `~/.config/obsidian`, `~/.config/discord`, `~/.config/BraveSoftware`,
`~/.config/chromium`, Steam and game configs, `~/.config/libreoffice`,
`~/.config/kdeconnect` (paired-device keys), `~/.histfile`, `~/.viminfo`,
`~/.python_history`.

### Reinstallable — bulk with no information in it

`~/.oh-my-zsh` (23 MB upstream clone), `~/.icons` (664 MB, comes from packages),
`~/.config/go` and `~/.config/nvm` (toolchain caches), `~/.tmux/plugins`
(`install.sh` clones tpm instead), IDE and vendor toolchain dirs (JetBrains,
Arduino, Microchip, SEGGER, espressif).

### Machine-specific — correct here, wrong there

These are gitignored and seeded from `templates/` by `install.sh`:

| File | Why it cannot be shared |
|---|---|
| `hypr/lua/monitors.lua` | Names outputs (`eDP-1`, `HDMI-A-1`) and modes that exist on one machine |
| `hypr/lua/workspaces.lua` | Pins workspaces to those output names |

`hypr/lua/laptop.lua` **is** tracked — it is mostly portable brightness/lid
binds. Its one hardware value, `TOUCHPAD_DEVICE`, is commented; find yours with
`hyprctl devices`.

### Generated — tracking them means permanent churn

`hypr/lua/colors.lua` and `~/.config/palette/build/` are rendered from
`palette.conf` by `palette-apply`. The palette is tracked; the renders are not.

### Backups and archives

The `*-backup-back-up_*` directories in `~/.config` and
`hypr-backup-*.tar.gz` are snapshots of older states, superseded by this repo's
history.

---

## Installing on a new machine

```sh
sudo pacman -S --needed git stow      # the only hard requirements
git clone <this-repo> ~/dotfiles
~/dotfiles/install.sh                 # --dry-run first if you like
```

`install.sh` is idempotent and non-destructive. Any real file that would block a
symlink is moved to `~/.dotfiles-backup-<timestamp>/` with its path preserved,
never deleted. Re-running repairs drift.

It then:

1. seeds `monitors.lua` and `workspaces.lua` from `templates/`, because
   `hyprland.lua` `require()`s them and a fresh clone has neither;
2. creates `~/.config/secrets.env` from its template, `chmod 600`;
3. stows every package;
4. renders the palette (`palette-apply`), clones tpm, copies in Claude settings;
5. runs `Hyprland --verify-config` and `zsh -n ~/.zshrc` and reports.

### Then, by hand

```sh
$EDITOR ~/.config/secrets.env                  # real OPENCLAW_TOKEN
cp ~/dotfiles/templates/gitconfig.example ~/.gitconfig
git config --global user.name  "…"
git config --global user.email "…"
~/.config/hypr/scripts/nwg-displays.sh         # lay out your monitors
sudo pacman -S --needed - < ~/dotfiles/packages/pacman-explicit.txt
yay      -S --needed - < ~/dotfiles/packages/aur.txt
hyprctl reload
```

Copy `~/.ssh` and `~/.gnupg` across yourself. They are not, and should not be,
in a git repo.

---

## Daily use

```sh
# edit anything under ~/.config as normal — it is already in the repo
$EDITOR ~/.config/hypr/lua/keybinds.lua   # Hyprland reloads on save

hyprctl configerrors                     # empty = fine

~/dotfiles/update.sh -m "add SUPER+P screenshot bind"
git -C ~/dotfiles push
```

On another machine:

```sh
git -C ~/dotfiles pull
~/dotfiles/install.sh      # only needed if packages were added or removed
```

`update.sh` also refreshes the package manifests, pulls back the copied Claude
settings, and greps staged content for anything that looks like a credential
before you commit.

---

## Changing things

| I want to… | Edit | Then |
|---|---|---|
| Add / change a keybind | `hypr/lua/keybinds.lua` — one `hl.bind(...)` line | saves reload automatically |
| Start an app at login | `hypr/lua/startup.lua` — add a line to the `autostart` list | next login |
| Change terminal / file manager / browser | `hypr/lua/defaults.lua` | — |
| Make an app float / size / pin to a workspace | `hypr/lua/windowrules.lua` (or add its class to the `settings` tag) | — |
| Change colors | `~/.config/palette/palette.conf` | `palette-apply` |
| Theme a new app from the palette | drop a template in `~/.config/palette/templates/`, add a line to `targets` | `palette-apply` |
| Gaps, borders, blur, rounding | `hypr/lua/decorations.lua` | — |
| Keyboard layouts, touchpad, mouse | `hypr/lua/settings.lua` | — |
| Add a script | put it in `hypr/scripts/`, `chmod +x`, bind it with `sh(s .. "/name.sh")` | — |
| Glass strength (how tinted / clear) | `panelTint`, `islandTint` in `quickshell/common/Theme.qml` | restart `qs -c glass` / the island |
| Pour speed / jelly amount | `openMs`, `closeMs`, `overshoot` in `quickshell/common/PourMotion.qml` | restart `qs -c glass` |
| Add a glass panel | new `quickshell/glass/Name.qml` (a `FocusScope` with `implicitWidth/Height`, `signal closeRequested()`, `function opened(arg)`), add it to the `switch` in `glass/GlassWindow.qml`, bind `glass.sh toggle name` | restart `qs -c glass` |
| Add a wallpaper effect | one line in the `FX` table in `hypr/scripts/wallpaper.sh` | — |

Scripts in `hypr/scripts/`: `volume` `brightness` `media` `screenshot`
`wallpaper` `zoom` `touchpad` `airplane` `bar` (top-bar mode) `glass` (open a
glass panel) `taskvim` `openclaw-tui` `nwg-displays`. Each one prints its usage when run with no
arguments.

---

## The Hyprland config in detail

The config uses the **Lua format** that Hyprland 0.57 requires. `~/.config/hypr/hyprland.lua` is the entry point;
it extends `package.path` and `require()`s modules from `lua/` in a fixed order
(later values win):

| Module | Holds |
|---|---|
| `keybinds.lua` | Every bind |
| `startup.lua` | `exec-once` autostarts |
| `env.lua` | Environment variables |
| `laptop.lua` | Lid switch, brightness keys, touchpad |
| `windowrules.lua` | Window rules, including the TUI workspace pinning |
| `decorations.lua` | Blur, shadows, rounding |
| `animations.lua` | Animation curves and speeds |
| `settings.lua` | Input, general, misc |
| `monitors.lua` | *Machine-specific* |
| `workspaces.lua` | *Machine-specific* |
| `dojo.lua` | SUPER+L → the dojo practice TUI |
| `colors.lua` | *Generated* by `palette-apply` from `~/.config/palette/palette.conf` |
| `defaults.lua` | Shared constants other modules `require` |

Two tools write into this directory, which is why the repo tolerates
symlinked directories rather than symlinked files:

- **palette-apply** renders `lua/colors.lua` from the palette
- **nwg-displays** can only emit `.conf`, so `scripts/nwg-displays.sh` wraps it
  and converts the output to Lua — always use the wrapper

There is one large trap in this Hyprland build, documented fully in
[docs/hyprland-lua.md](docs/hyprland-lua.md): **`hyprctl dispatch` arguments are
evaluated as Lua**, so the legacy `hyprctl dispatch workspace 8` form is a
syntax error, not a command. Scripts written against the old syntax fail
silently. `hyprctl keyword` does not work at all — change options at runtime
with `hyprctl eval 'hl.config({ ... })'` instead (see `scripts/zoom.sh`).
Read that file before touching any script that calls `hyprctl`.

---

## Keybindings worth knowing

`SUPER + H` opens a searchable list of every bind (from `shortcuts.md`). A few
worth knowing:

| Bind | Action |
|---|---|
| `SUPER + T` | taskvim → workspace 8, fullscreen |
| `SUPER + A` | OpenClaw TUI → workspace 5, fullscreen |
| `SUPER + L` | dojo practice TUI → workspace 7, fullscreen |
| `SUPER + W` | Wallpaper picker |
| `SUPER + SHIFT + B` | Top bar: waybar → Peek → Dynamic Island |

The three TUI launchers share a pattern worth reusing: a script focuses the
target workspace and launches the app with a **unique `--class`**, while window
rules in `windowrules.lua` pin that class to its workspace and force fullscreen.
Placement happens before the window maps, so there is no flicker and no
`sleep`-based race. Re-pressing the key focuses the existing instance instead of
spawning a second one.

---

## Troubleshooting

**`stow: WARNING! stowing X would cause conflicts`** — a real file occupies the
target path. `install.sh` moves those aside automatically; if you ran `stow`
by hand, move the file yourself and retry.

**Hyprland will not start after a pull** — run `Hyprland --verify-config` from a
TTY. The usual cause is a missing gitignored file: `colors.lua` (run
`palette-apply`) or `monitors.lua` (`./install.sh` reseeds it).

**A keybinding does nothing** — check whether its script uses legacy
`hyprctl dispatch` syntax. See [docs/hyprland-lua.md](docs/hyprland-lua.md).
`hyprctl` exits non-zero but most call sites discard it, so the failure is
invisible.

**Colours look wrong / everything is default** — run `palette-apply`.

**Edits do not show in `git status`** — the path is probably gitignored
(generated or machine-specific). Confirm with
`git -C ~/dotfiles check-ignore -v <path>`.

**Undo everything** — `~/dotfiles/uninstall.sh --restore` removes the symlinks
and copies real files back into `$HOME`.

---

## Design decisions

**Symlinks, not copies.** A copy-based repo needs a sync step before every
commit, and the day you forget is the day the repo silently stops matching
reality. Symlinks make drift impossible.

**Directory-level symlinks.** `~/.config/hypr` is one symlink rather than a
symlink per file. Tools that write into that directory (palette-apply, nwg-displays)
work unchanged, and new files appear in the repo automatically instead of
needing a re-stow.

**Secrets in a file, not stripped out.** Deleting the token would have broken
the `octui` alias and the `SUPER+A` launcher. Both now source
`~/.config/secrets.env`, which stays local. The config in the repo is complete
and functional; only the value is absent.

**Package manifests, not a lockfile.** Pinning versions across time on a rolling
distro creates unsatisfiable dependency sets. An explicit-package list restores
intent, and pacman resolves the rest.

**The nvim upstream `.git` was renamed, not deleted.** It sits at
`nvim/.config/nvim/.git.disabled` (gitignored). Git will not treat the directory
as a nested repo, and renaming it back restores the link to kickstart.nvim.
