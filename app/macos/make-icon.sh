#!/bin/bash
# Regenerate AppIcon.icns from logo.png (the EASy68K wordmark) — the logo
# centred on a soft cool-white rounded-square background. Requires ImageMagick.
set -e
cd "$(dirname "$0")"
W=/tmp/easy68k_iconwork
mkdir -p "$W" "$W/AppIcon.iconset"

magick -size 1024x1024 gradient:'#f3f6fb'-'#dde6f2' "$W/bg.png"
magick -size 1024x1024 xc:none -draw "roundrectangle 0,0,1023,1023,200,200" "$W/mask.png"
magick "$W/bg.png" "$W/mask.png" -alpha Off -compose CopyOpacity -composite "$W/round_bg.png"
magick logo.png -resize 860x "$W/logo_big.png"
magick "$W/round_bg.png" "$W/logo_big.png" -gravity center -composite "$W/icon_1024.png"
cp "$W/icon_1024.png" AppIcon-master.png

gen(){ sips -z "$2" "$2" "$W/icon_1024.png" --out "$W/AppIcon.iconset/icon_$1.png" >/dev/null 2>&1; }
gen 16x16 16;    gen 16x16@2x 32
gen 32x32 32;    gen 32x32@2x 64
gen 128x128 128; gen 128x128@2x 256
gen 256x256 256; gen 256x256@2x 512
gen 512x512 512; gen 512x512@2x 1024
iconutil -c icns "$W/AppIcon.iconset" -o AppIcon.icns
echo "wrote AppIcon.icns"
