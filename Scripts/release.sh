#!/bin/bash
# A signed, notarized Tally.dmg for a GitHub release. Usage: Scripts/release.sh X.Y.Z
# Needs a Developer ID Application certificate and a notarytool keychain profile (TALLY_NOTARY_PROFILE, default notch-notary).
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: Scripts/release.sh X.Y.Z}"
PROFILE="${TALLY_NOTARY_PROFILE:-notch-notary}"
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
[ -n "$IDENTITY" ] || { echo "No Developer ID Application certificate in the keychain."; exit 1; }

BUDGET_SIGN_IDENTITY="$IDENTITY" Scripts/make-app.sh release
APP="build/Tally.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
# Hardened runtime and a secure timestamp: what notarization asks for.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

DMG="build/Tally-$VERSION.dmg"
Scripts/make-dmg.sh "$APP" "$DMG" # the designed installer window
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
echo "Built $DMG"
