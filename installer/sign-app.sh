#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# sign-app.sh — build + codesign build/EASy68K.app with a Developer ID identity
# and the hardened runtime (required for notarization).
#
# The bundle is a single GUI binary (Contents/MacOS/EASy68K) plus the sim68k CLI
# (Contents/MacOS/sim68k). The app is NOT sandboxed and loads only system
# frameworks, so no entitlements are required. Each Mach-O is signed; the app
# sign then seals the bundle.
#
# Config comes from signing.env (gitignored):
#   SIGN_IDENTITY   "Developer ID Application: NAME (TEAMID)"
#   TEAM_ID         10-char Apple Team ID
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f signing.env ] && set -a && . ./signing.env && set +a
SIGN_IDENTITY="${SIGN_IDENTITY:?set SIGN_IDENTITY (see signing.env)}"
TEAM_ID="${TEAM_ID:?set TEAM_ID (see signing.env)}"
APP="build/EASy68K.app"

# ── 0. preflight: prove the Developer ID key is reachable by codesign ────────
echo "── preflight: verifying signing identity is reachable"
if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null | grep -qF "${SIGN_IDENTITY}"; then
    echo "FAIL: signing identity not found in any keychain:" >&2
    echo "      ${SIGN_IDENTITY}" >&2
    exit 1
fi
scratch="$(mktemp -t e68_signtest)"; printf 'signtest' > "${scratch}"
if ! /usr/bin/codesign --force --timestamp=none --sign "${SIGN_IDENTITY}" "${scratch}" >/dev/null 2>&1; then
    rm -f "${scratch}"
    echo "FAIL: codesign cannot use the private key non-interactively." >&2
    echo "      security unlock-keychain ~/Library/Keychains/login.keychain-db" >&2
    echo "      security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k <pwd> ~/Library/Keychains/login.keychain-db" >&2
    exit 1
fi
rm -f "${scratch}"
echo "── preflight OK: codesign can use ${SIGN_IDENTITY}"

# ── 1. build the app ────────────────────────────────────────────────────────
echo "── building ${APP}"
make app

[ -d "${APP}" ] || { echo "FAIL: ${APP} not found after build" >&2; exit 1; }

# ── 2. sign the bundled sim68k CLI (hardened runtime) ───────────────────────
if [ -f "${APP}/Contents/MacOS/sim68k" ]; then
    echo "── codesigning sim68k"
    /usr/bin/codesign --force --options runtime --timestamp \
        --sign "${SIGN_IDENTITY}" \
        --identifier "com.easy68k.macos.sim68k" \
        "${APP}/Contents/MacOS/sim68k"
fi

# ── 3. sign the app bundle (hardened runtime, seals everything) ─────────────
echo "── codesigning app bundle"
/usr/bin/codesign --force --options runtime --timestamp \
    --sign "${SIGN_IDENTITY}" \
    "${APP}"

# ── 4. verify ───────────────────────────────────────────────────────────────
echo "── verifying signatures"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${APP}"
/usr/bin/codesign --display --verbose=2 "${APP}" 2>&1 \
    | grep -E "^(Identifier|TeamIdentifier|Authority|Timestamp)=" | head

echo ""
echo "  → ${APP}  (signed, hardened runtime)"
