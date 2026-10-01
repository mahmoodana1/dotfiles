#!/usr/bin/env bash
# Wire the Glass mod into every Firefox profile that runs Sine.
# Idempotent. Run with Firefox closed (Sine rewrites mods.json on exit).
#
#   ~/.config/firefox/link.sh
#
# Then, once per profile: Vimium C options -> "Import settings" ->
# ~/.config/firefox/vimium-c.json
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF="$HOME/.mozilla/firefox"

pgrep -x firefox >/dev/null && { echo "close Firefox first"; exit 1; }

merge_prefs() {   # $1 = a profile's user.js
    touch "$1"
    python3 - "$1" "$HERE/user.js" <<'PY'
import sys, re
dst, src = sys.argv[1], sys.argv[2]
begin, end = "// >>> glass prefs (~/.config/firefox/user.js)", "// <<< glass prefs"
text = open(dst).read()
text = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.S)
# drop the one-line pref older link.sh versions appended
text = re.sub(r"\n?// Glass mod \(~/.config/firefox\): let Sine run its local vimkeys.uc.js\nuser_pref\(\"sine.allow-unsafe-js\", true\);\n", "\n", text)
open(dst, "w").write(text.rstrip("\n") + "\n\n" + begin + "\n" + open(src).read().rstrip("\n") + "\n" + end + "\n")
PY
}

for chrome in "$FF"/*/chrome; do
    mods="$chrome/sine-mods/mods.json"
    [ -f "$mods" ] || continue
    profile="$(dirname "$chrome")"

    ln -sfn "$HERE/glass" "$chrome/sine-mods/glass"

    # enable glass, turn off Nebula (a Zen Browser theme; misfires on Firefox)
    tmp="$(mktemp)"
    jq '.glass = {
          id: "glass", name: "Glass", enabled: true, "no-updates": true,
          description: "black glass + vim keys (~/.config/firefox)",
          style: { chrome: "userChrome.css", content: "userContent.css" },
          scripts: { "vimkeys.uc.js": { include: ["chrome://browser/content/browser.xhtml"] } }
        }
        | if .Nebula then .Nebula.enabled = false else . end' "$mods" > "$tmp"
    mv "$tmp" "$mods"

    # prefs: replace the marked block in user.js with ./user.js
    merge_prefs "$profile/user.js"

    echo "linked: $profile"
done
