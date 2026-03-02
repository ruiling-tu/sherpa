#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/source-image.png"
  exit 1
fi

SRC="$1"
OUT_DIR="BoulderLog/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT_DIR"

# Center-crop to square and normalize to 1024x1024.
sips -c 1024 1024 "$SRC" --out "$TMP/icon-1024.png" >/dev/null
sips -z 1024 1024 "$TMP/icon-1024.png" --out "$TMP/icon-1024.png" >/dev/null

sizes=(
  "20 2 iphone 20@2x"
  "20 3 iphone 20@3x"
  "29 2 iphone 29@2x"
  "29 3 iphone 29@3x"
  "40 2 iphone 40@2x"
  "40 3 iphone 40@3x"
  "60 2 iphone 60@2x"
  "60 3 iphone 60@3x"
  "20 1 ipad 20@1x"
  "20 2 ipad 20@2x"
  "29 1 ipad 29@1x"
  "29 2 ipad 29@2x"
  "40 1 ipad 40@1x"
  "40 2 ipad 40@2x"
  "76 1 ipad 76@1x"
  "76 2 ipad 76@2x"
  "83.5 2 ipad 83_5@2x"
)

for spec in "${sizes[@]}"; do
  read -r point scale idiom suffix <<<"$spec"
  px=$(python3 - <<PY
point = float("$point")
scale = int("$scale")
print(int(round(point * scale)))
PY
)
  out="$OUT_DIR/Icon-${suffix}.png"
  sips -z "$px" "$px" "$TMP/icon-1024.png" --out "$out" >/dev/null
  echo "Generated $out"
done

cp "$TMP/icon-1024.png" "$OUT_DIR/Icon-1024.png"

echo "Done. AppIcon images generated in $OUT_DIR"
