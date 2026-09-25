#!/usr/bin/env bash
# One-shot system stats for the Peek bar, as key=value lines.
read -r _ u n s i w q sq st _ < /proc/stat
echo "cpu=$((u+n+s+q+sq+st)) $((u+n+s+q+sq+st+i+w))"
awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "mem=%d\n", (t-a)*100/t}' /proc/meminfo
for z in /sys/class/thermal/thermal_zone*; do
  [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ] && { echo "temp=$(( $(cat "$z/temp") / 1000 ))"; break; }
done
echo "disk=$(df --output=pcent / | tail -1 | tr -dc 0-9)"
echo "net=$(nmcli -t -f STATE general 2>/dev/null)"
