#!/usr/bin/env bash
# =====================================================================
#  Refresh the parts of this repo that are snapshots rather than
#  symlinks, then show what changed.
#
#      ~/dotfiles/update.sh            # refresh + report
#      ~/dotfiles/update.sh -m "msg"   # refresh + commit everything
#
#  Config files themselves need no syncing: ~/.config/hypr and friends
#  are symlinks into this repo, so edits are already here. What this
#  script picks up is the handful of things that are copied, not linked.
# =====================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

MSG=""
[ "${1:-}" = "-m" ] && MSG="${2:-}"

c_ok=$'\e[32m'; c_hdr=$'\e[36m'; c_off=$'\e[0m'
say() { printf '%s==>%s %s\n' "$c_hdr" "$c_off" "$*"; }
ok()  { printf '  %s✓%s %s\n' "$c_ok" "$c_off" "$*"; }

# ---------------------------------------------------------------------
# 1. Package manifests
# ---------------------------------------------------------------------
if command -v pacman >/dev/null; then
    say "Refreshing package manifests"
    pacman -Qqen > packages/pacman-explicit.txt
    pacman -Qqem > packages/aur.txt
    ok "$(wc -l < packages/pacman-explicit.txt) native, $(wc -l < packages/aur.txt) AUR"
fi

# ---------------------------------------------------------------------
# 2. Copied-not-linked files
#    Claude Code rewrites settings.json in place, so it is deployed as a
#    copy. Pull the live version back in.
# ---------------------------------------------------------------------
say "Refreshing copied files"
if [ -f "$HOME/.claude/settings.json" ]; then
    cp "$HOME/.claude/settings.json" claude/.claude/settings.json
    ok "claude/.claude/settings.json"
fi

# ---------------------------------------------------------------------
# 3. Guard: nothing secret may enter a commit.
#    Cheap grep, deliberately noisy. A false positive costs you ten
#    seconds; a false negative publishes a live credential.
# ---------------------------------------------------------------------
say "Scanning staged content for secrets"
leaks=$(git diff --cached --name-only 2>/dev/null | while read -r f; do
    [ -f "$f" ] || continue
    grep -ilE '(token|secret|api[_-]?key|password)[^a-z]{0,3}[:=][^a-z]{0,3}[a-z0-9_/+.-]{16,}|ghp_[a-z0-9]{20,}|sk-[a-z0-9]{20,}' "$f" || true
done)
if [ -n "$leaks" ]; then
    printf '\e[31m  ! possible secrets in:\e[0m\n%s\n' "$leaks"
    printf '  Review before committing. Move real values to ~/.config/secrets.env.\n'
fi

# ---------------------------------------------------------------------
# 4. Report or commit
# ---------------------------------------------------------------------
if [ -z "$(git status --porcelain)" ]; then
    say "Nothing changed"
    exit 0
fi

say "Changes"
git status --short

if [ -n "$MSG" ]; then
    git add -A
    git commit -q -m "$MSG"
    ok "committed: $MSG"
    printf '  push with:  git -C %s push\n' "$DOTFILES"
else
    printf '\nCommit with:  %s/update.sh -m "what you changed"\n' "$DOTFILES"
fi
