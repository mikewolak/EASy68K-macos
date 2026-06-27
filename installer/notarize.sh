#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# notarize.sh — submit a .pkg (or .dmg) to Apple notarization and staple.
#
# Usage:  installer/notarize.sh <path-to-pkg-or-dmg>
#
# Prerequisite (one-time):
#
#   xcrun notarytool store-credentials AC_PASSWORD \
#       --apple-id   <your-apple-id@example.com> \
#       --team-id    <TEAM_ID> \
#       --password   <app-specific-password>
#
# Generate the app-specific password at https://appleid.apple.com →
# Sign-In and Security → App-Specific Passwords. The credentials profile
# name is hard-coded here as AC_PASSWORD; override with NOTARY_PROFILE.
#
# Notarization typically takes 1–5 minutes. This script blocks until done
# (`notarytool submit --wait`) and then staples the ticket so Gatekeeper
# can validate offline.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# Pull the notarytool keychain-profile name from signing.env (gitignored) so no
# project-specific identifiers live in the repo. Falls back to a generic name.
# Source via the script's own path so a relative ARTIFACT still resolves from
# the caller's working directory.
_ENV="$(cd "$(dirname "$0")/.." && pwd)/signing.env"
[ -f "${_ENV}" ] && set -a && . "${_ENV}" && set +a
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

if [ $# -ne 1 ]; then
    echo "usage: $0 <path-to-pkg-or-dmg>" >&2
    exit 2
fi

ARTIFACT="$1"

if [ ! -f "${ARTIFACT}" ]; then
    echo "FAIL: ${ARTIFACT} not found" >&2
    exit 1
fi

case "${ARTIFACT}" in
    *.pkg|*.dmg|*.zip) ;;
    *) echo "FAIL: artifact must be .pkg, .dmg, or .zip (got ${ARTIFACT})" >&2; exit 1 ;;
esac

# Sanity: profile exists
if ! /usr/bin/xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" \
       >/dev/null 2>&1; then
    echo "FAIL: notarytool profile '${NOTARY_PROFILE}' not found in keychain." >&2
    echo "      Run, one time:" >&2
    echo "        xcrun notarytool store-credentials ${NOTARY_PROFILE} \\" >&2
    echo "            --apple-id <your-apple-id> \\" >&2
    echo "            --team-id <TEAM_ID> \\" >&2
    echo "            --password <app-specific-password>" >&2
    exit 1
fi

echo "── submitting ${ARTIFACT} to Apple notarization (profile: ${NOTARY_PROFILE})"
echo "   (this typically takes 1–5 minutes)"
/usr/bin/xcrun notarytool submit "${ARTIFACT}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo ""
echo "── stapling notarization ticket"
/usr/bin/xcrun stapler staple "${ARTIFACT}"
/usr/bin/xcrun stapler validate "${ARTIFACT}"

echo ""
echo "── verifying Gatekeeper assessment"
case "${ARTIFACT}" in
    *.pkg)
        /usr/sbin/spctl --assess --type install --verbose=2 "${ARTIFACT}" || true
        ;;
    *.dmg)
        /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "${ARTIFACT}" || true
        ;;
esac

echo ""
echo "  → ${ARTIFACT}  (notarized + stapled)"
