#!/usr/bin/env bash
# Fetch the new tab page's wallpapers (one picked at random per tab, see
# newtab.sys.mjs) into ./wallpapers. Not committed: they're other people's
# art, pulled from wallhaven.cc. Idempotent; needs curl + ImageMagick.
#
# Encoded at the screens' size (SIZE) as JPEG: drawn 1:1, no rescaled
# re-decode, and JPEG decodes fastest, so a new tab shows it instantly.
set -euo pipefail

SIZE=1920x1080

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wallpapers"
mkdir -p "$DIR"

WALLS=(
    e8/wallhaven-e83ve8.jpg   # aurora over a mountain lake
    xe/wallhaven-xe72dz.jpg   # pink/violet nebula
    je/wallhaven-jexr5q.jpg   # neon city street
    ml/wallhaven-mlyx18.jpg   # sunset portal on the sea
    og/wallhaven-oglpgm.jpg   # liquid colour waves
    w5/wallhaven-w5mzmx.jpg   # glossy violet blob
    7j/wallhaven-7jr9we.jpg   # synthwave arch
    ml/wallhaven-ml3oqk.png   # aurora over purple peaks
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for i in "${!WALLS[@]}"; do
    out="$DIR/$((i + 1)).jpg"
    [ -s "$out" ] && continue
    src="$tmp/src.${WALLS[i]##*.}"
    curl -sfL --retry 3 --retry-all-errors -o "$src" "https://w.wallhaven.cc/full/${WALLS[i]}"
    magick "$src" -resize "$SIZE^" -gravity center -extent "$SIZE" -strip \
        -sampling-factor 4:2:0 -quality 90 "$out"
    echo "fetched: $out"
done
