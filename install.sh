#!/usr/bin/env bash
# =====================================================================
#  Deploy these dotfiles onto a machine.
#
#      git clone <this-repo> ~/dotfiles && ~/dotfiles/install.sh
#
#  Everything here is idempotent: run it as often as you like. It never
#  deletes a file it did not create — where a real config already exists,
#  it backs the file up to ~/.dotfiles-backup-<timestamp>/ first.
#
#  Flags:
#      --dry-run   show what would happen, change nothing
#      --packages "hypr nvim"   deploy only these stow packages
# =====================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
PACKAGES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)  DRY_RUN=1; shift ;;
        --packages) PACKAGES="$2"; shift 2 ;;
        -h|--help)  sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
done

# ---------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------
c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_hdr=$'\e[36m'; c_off=$'\e[0m'
say()  { printf '%s==>%s %s\n' "$c_hdr" "$c_off" "$*"; }
ok()   { printf '  %s✓%s %s\n'  "$c_ok"  "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n'  "$c_warn" "$c_off" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

[ "$DRY_RUN" = 1 ] && warn "dry run — nothing will be modified"

# ---------------------------------------------------------------------
# 0. Prerequisites
# ---------------------------------------------------------------------
say "Checking prerequisites"
command -v git  >/dev/null || die "git is required"
command -v stow >/dev/null || die "GNU stow is required — install it first (pacman -S stow)"
ok "git and stow present"

# ---------------------------------------------------------------------
# 1. Machine-specific files that must exist BEFORE Hyprland parses its
#    config. These are gitignored, so a fresh clone does not have them,
#    and hyprland.lua require()s every one of them.
# ---------------------------------------------------------------------
say "Seeding machine-specific files from templates/"

seed() {  # seed <template> <destination>
    local src="$DOTFILES/templates/$1" dst="$2"
    if [ -e "$dst" ]; then
        ok "$(basename "$dst") already present — left alone"
    else
        run mkdir -p "$(dirname "$dst")"
        run cp "$src" "$dst"
        ok "created $dst"
    fi
}

HYPR_LUA="$DOTFILES/hypr/.config/hypr/lua"
seed monitors.lua.example   "$HYPR_LUA/monitors.lua"
seed workspaces.lua.example "$HYPR_LUA/workspaces.lua"
seed colors.lua.example     "$HYPR_LUA/colors.lua"

# animations.lua is whichever preset was last chosen in the Animations.sh
# picker; ship the upstream default so the config parses on a clean machine.
if [ ! -e "$HYPR_LUA/animations.lua" ]; then
    run cp "$DOTFILES/hypr/.config/hypr/animations/00-default.lua" "$HYPR_LUA/animations.lua"
    ok "created animations.lua (00-default preset)"
else
    ok "animations.lua already present — left alone"
fi

# ---------------------------------------------------------------------
# 2. Secrets
# ---------------------------------------------------------------------
say "Setting up ~/.config/secrets.env"
if [ -e "$HOME/.config/secrets.env" ]; then
    ok "secrets.env already present — left alone"
else
    run mkdir -p "$HOME/.config"
    run cp "$DOTFILES/templates/secrets.env.example" "$HOME/.config/secrets.env"
    run chmod 600 "$HOME/.config/secrets.env"
    warn "created ~/.config/secrets.env with PLACEHOLDER values — edit it"
fi

# ---------------------------------------------------------------------
# 3. Move conflicting real files out of the way.
#    stow refuses to overwrite a regular file, and rightly so. Anything
#    that would collide gets moved into a timestamped backup directory,
#    preserving its path so you can put it back by hand.
# ---------------------------------------------------------------------
if [ -z "$PACKAGES" ]; then
    # Every directory that is a stow package: has a dot-file/dot-dir inside.
    # 'claude' is excluded on purpose: Claude Code rewrites settings.json in
    # place, which would clobber the repo copy through a symlink. It is
    # deployed by copy in the post-link step instead.
    PACKAGES="$(cd "$DOTFILES" && for d in */; do
        d="${d%/}"
        case "$d" in templates|docs|packages|claude|.git) continue ;; esac
        [ -n "$(find "$d" -maxdepth 1 -name '.*' -print -quit)" ] && printf '%s ' "$d"
    done)"
fi
say "Packages: $PACKAGES"

say "Backing up conflicting files to $BACKUP"
conflicts=0
for pkg in $PACKAGES; do
    [ -d "$DOTFILES/$pkg" ] || { warn "no such package: $pkg"; continue; }
    # Enumerate the target path of every file the package provides.
    while IFS= read -r rel; do
        target="$HOME/$rel"
        # A symlink already pointing into this repo is a previous run: fine.
        if [ -L "$target" ]; then
            case "$(readlink -f "$target" 2>/dev/null)" in
                "$DOTFILES"/*) continue ;;
            esac
        fi
        [ -e "$target" ] || continue
        [ -L "$target" ] && continue
        run mkdir -p "$BACKUP/$(dirname "$rel")"
        run mv "$target" "$BACKUP/$rel"
        warn "moved aside: ~/$rel"
        conflicts=$((conflicts + 1))
    done < <(cd "$DOTFILES/$pkg" && find . -type f -o -type l | sed 's|^\./||')
done
[ "$conflicts" -eq 0 ] && ok "no conflicts"

# ---------------------------------------------------------------------
# 4. Stow — creates the symlinks. -R restows, so re-running heals
#    anything that drifted.
# ---------------------------------------------------------------------
say "Linking with stow"
for pkg in $PACKAGES; do
    [ -d "$DOTFILES/$pkg" ] || continue
    if run stow -d "$DOTFILES" -t "$HOME" -R "$pkg"; then
        ok "$pkg"
    else
        die "stow failed on '$pkg' — resolve the conflict above and re-run"
    fi
done

# ---------------------------------------------------------------------
# 5. Things stow cannot express
# ---------------------------------------------------------------------
say "Post-link steps"

# tmux plugin manager: upstream clone, deliberately not vendored.
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    run git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    ok "cloned tpm — press prefix + I inside tmux to install plugins"
else
    ok "tpm already installed"
fi

# ~/.gitconfig is not stowed: it holds your name and email.
if [ ! -e "$HOME/.gitconfig" ]; then
    warn "no ~/.gitconfig — copy templates/gitconfig.example and set your identity:"
    printf '      cp %s/templates/gitconfig.example ~/.gitconfig\n' "$DOTFILES"
    printf '      git config --global user.name  "Your Name"\n'
    printf '      git config --global user.email "you@example.com"\n'
else
    ok "~/.gitconfig present"
fi

# Claude Code settings: copied rather than symlinked, because the app
# rewrites the file in place and would otherwise clobber the repo copy.
if [ ! -e "$HOME/.claude/settings.json" ]; then
    run mkdir -p "$HOME/.claude"
    run cp "$DOTFILES/claude/.claude/settings.json" "$HOME/.claude/settings.json"
    ok "installed ~/.claude/settings.json"
else
    ok "~/.claude/settings.json present — left alone (diff it against claude/ by hand)"
fi

# Scripts lose their +x bit through some transfer paths; assert it.
run find "$DOTFILES/hypr/.config/hypr" -name '*.sh' -exec chmod +x {} +
ok "hypr scripts marked executable"

# ---------------------------------------------------------------------
# 6. Validate
# ---------------------------------------------------------------------
say "Validating"
if command -v Hyprland >/dev/null && [ "$DRY_RUN" = 0 ]; then
    if Hyprland --verify-config 2>&1 | grep -q "config ok"; then
        ok "Hyprland config parses"
    else
        warn "Hyprland --verify-config reported problems — run it directly to see them"
    fi
else
    warn "Hyprland not installed here — skipping config check"
fi

if command -v zsh >/dev/null && [ "$DRY_RUN" = 0 ]; then
    zsh -n "$HOME/.zshrc" 2>/dev/null && ok "zshrc parses" || warn "zshrc has syntax errors"
fi

cat <<EOF

$(printf '%s' "$c_ok")Done.$(printf '%s' "$c_off")

Next steps on a new machine:
  1. Put your real token in  ~/.config/secrets.env
  2. Set your git identity   (see above)
  3. Lay out your displays   ~/.config/hypr/scripts/nwg-displays.sh
  4. Install packages        sudo pacman -S --needed - < $DOTFILES/packages/pacman-explicit.txt
                             yay -S --needed - < $DOTFILES/packages/aur.txt
  5. Reload Hyprland         hyprctl reload
EOF
[ "$conflicts" -gt 0 ] && printf 'Displaced files are in %s\n' "$BACKUP"
exit 0
