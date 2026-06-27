#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# build-dmg.sh — wrap build/EASy68K.app in a distributable .dmg.
#
# Standard drag-to-install layout: EASy68K.app + an Applications symlink.
# Uses hdiutil makehybrid (not `create -srcfolder`) so macOS never mounts and
# scans the .app (which fails with "Resource busy").
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-5.16.1}"
APP="build/EASy68K.app"
DMG_OUT="build/installer/EASy68K-${VERSION}.dmg"
STAGE="build/installer/dmg-stage"
VOL_NAME="EASy68K ${VERSION}"

[ -d "${APP}" ] || { echo "FAIL: ${APP} not found. Run installer/sign-app.sh first." >&2; exit 1; }

echo "── staging DMG contents at ${STAGE}"
rm -rf "${STAGE}"; mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

mkdir -p "$(dirname "${DMG_OUT}")"
rm -f "${DMG_OUT}" "${DMG_OUT}.rw.dmg"

echo "── building ${DMG_OUT}"
/usr/bin/hdiutil makehybrid -hfs \
    -default-volume-name "${VOL_NAME}" \
    -o "${DMG_OUT}.rw.dmg" "${STAGE}"
/usr/bin/hdiutil convert "${DMG_OUT}.rw.dmg" -format UDZO -ov -o "${DMG_OUT}"
rm -f "${DMG_OUT}.rw.dmg"
rm -rf "${STAGE}"

echo ""
echo "  → ${DMG_OUT}"
ls -lh "${DMG_OUT}" | awk '{print "    " $5 "  " $9}'
