#!/usr/bin/env bash
# =====================================================================
#  Remove the symlinks this repo created, leaving ~ as stow found it.
#
#      ~/dotfiles/uninstall.sh              # unlink everything
#      ~/dotfiles/uninstall.sh --restore    # unlink, then copy the real
#                                           # files back into place
#
#  Without --restore your configs vanish from ~ (they still exist here in
#  the repo, untouched). With it, you get independent copies back and can
#  delete ~/dotfiles entirely.
# =====================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE=0
[ "${1:-}" = "--restore" ] && RESTORE=1

c_ok=$'\e[32m'; c_hdr=$'\e[36m'; c_off=$'\e[0m'
say() { printf '%s==>%s %s\n' "$c_hdr" "$c_off" "$*"; }
ok()  { printf '  %s✓%s %s\n' "$c_ok" "$c_off" "$*"; }

PACKAGES="$(cd "$DOTFILES" && for d in */; do
    d="${d%/}"
    case "$d" in templates|docs|packages|claude|.git) continue ;; esac
    [ -n "$(find "$d" -maxdepth 1 -name '.*' -print -quit)" ] && printf '%s ' "$d"
done)"

say "Unlinking: $PACKAGES"
for pkg in $PACKAGES; do
    stow -d "$DOTFILES" -t "$HOME" -D "$pkg" && ok "$pkg"
done

if [ "$RESTORE" = 1 ]; then
    say "Copying real files back into \$HOME"
    for pkg in $PACKAGES; do
        # -T dereferences nothing here; a plain recursive copy is what we
        # want, since the repo holds regular files.
        cp -a "$DOTFILES/$pkg/." "$HOME/"
        ok "$pkg"
    done
    say "Done — ~/dotfiles can now be deleted"
else
    say "Done — configs remain in $DOTFILES; re-run install.sh to relink"
fi
