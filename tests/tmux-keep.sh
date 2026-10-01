#!/usr/bin/env bash
# Test for local/.local/bin/tmux-keep restore: the session that starts the tmux
# server (the project you open first after a reboot) must get its saved windows
# back, a session built by hand must be left alone.
# Runs against a private tmux server + private data dir; never touches the real ones.
#   tests/tmux-keep.sh
KEEP=${KEEP:-$(dirname "$(readlink -f "$0")")/../local/.local/bin/tmux-keep}
T=$(mktemp -d)
export TMUX_TMPDIR=$T XDG_DATA_HOME=$T/data XDG_RUNTIME_DIR=$T SHELL=/bin/sh
unset TMUX TMUX_PANE
trap 'tmux kill-server 2>/dev/null; rm -rf "$T"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
wins() { tmux list-windows -t "=$1" -F '#{window_index}:#{window_name}' 2>&1 | paste -sd' '; }

mkdir -p "$T/data/tmux-keep" "$T/proj" "$T/other" "$T/busy"
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }
{   #   session win name  rename layout wact pane pact cwd      run
    row busy  0 one   fixed x 1 0 1 "$T/busy"  ""
    row other 0 solo  fixed x 1 0 1 "$T/other" ""
    row proj  0 edit  fixed x 0 0 1 "$T/proj"  ""
    row proj  1 git   fixed x 1 0 1 "$T/proj"  ""
    row proj  1 git   fixed x 1 1 0 "$T/proj"  ""
    row proj  2 agent fixed x 0 0 1 "$T/proj"  ""
} > "$T/data/tmux-keep/snapshot.tsv"

# what the sessionizer does on a fresh boot: this starts the server
tmux -f /dev/null new-session -ds proj -c "$T/proj"
tmux set -g pane-base-index 0
# a session somebody already built by hand before restore ran: must be left alone
tmux new-session -ds busy -c "$T/busy" -n mine
tmux new-window -d -t =busy: -n mine2
# a client sitting in the blank session, like the terminal the sessionizer opened
script -qfc "tmux attach -t =proj" /dev/null >/dev/null 2>&1 &
for _ in $(seq 50); do [ -n "$(tmux list-clients)" ] && break; sleep 0.1; done

"$KEEP" restore

check "opener session gets its saved windows" "$(wins proj)"  "0:edit 1:git 2:agent"
check "opener session: split pane restored"   "$(tmux list-panes -t =proj:1 | wc -l)" "2"
check "opener session: active window"         "$(tmux display -p -t =proj: '#{window_name}')" "git"
check "client stayed in its session"          "$(tmux list-clients -F '#{session_name}')" "proj"
check "missing session restored"              "$(wins other)" "0:solo"
check "hand-built session untouched"          "$(wins busy)"  "0:mine 1:mine2"
check "no leftover helper sessions"           "$(tmux list-sessions -F '#{session_name}' | paste -sd' ')" "busy other proj"
check "restore flagged done"                  "$(tmux show -gqv @keep-restored)" "1"

# a second restore (re-sourcing the config) must not bring anything back
tmux kill-session -t =other
"$KEEP" restore
check "second restore is a no-op"             "$(tmux list-sessions -F '#{session_name}' | paste -sd' ')" "busy proj"
exit $fail
