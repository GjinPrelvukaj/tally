#!/bin/bash
# The installer: a DMG whose window shows the background (Scripts/dmg-background.swift), the app
# and an Applications shortcut standing on its ledge, no toolbar, and Tally's icon on the disk. As Brimlight's.
# Usage: Scripts/make-dmg.sh APP DMG
# Finder lays the window out, so the first run asks once to let Terminal control Finder.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$1"
DMG="$2"
NAME="Tally"
WORK="build/dmg-work"
RW="$WORK/rw.dmg"
rm -rf "$WORK" "$DMG"
mkdir -p "$WORK/stage/.background"

# The background, at 1x and 2x in one file, so it is sharp on any display.
swift Scripts/dmg-background.swift "$WORK/background" > /dev/null
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/stage/.background/background.tiff" > /dev/null
cp -R "$APP" "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"

# Writable first, so Finder can lay it out; squeezed afterwards.
hdiutil create -volname "$NAME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$RW" > /dev/null
# A disk of the same name already open would take the layout instead.
[ -d "/Volumes/$NAME" ] && hdiutil detach "/Volumes/$NAME" -force > /dev/null || true
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/Apple_HFS/ {print $1}')
VOLUME="/Volumes/$NAME"

# The disk's own icon.
cp "$APP/Contents/Resources/AppIcon.icns" "$VOLUME/.VolumeIcon.icns"
SetFile -c icnC "$VOLUME/.VolumeIcon.icns"
SetFile -a C "$VOLUME"

# The window: 640 by 420 (plus its title bar), icons 128 points, the app on the left, Applications
# on the right, both standing on the ledge drawn in the background.
osascript <<OSA
tell application "Finder"
    tell disk "$NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 568}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 128
        set text size of options to 12
        set background picture of options to file ".background:background.tiff"
        set position of item "$(basename "$APP")" of container window to {214, 250}
        set position of item "Applications" of container window to {426, 250}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
OSA

chmod -Rf go-w "$VOLUME" || true
sync
hdiutil detach "$DEVICE" > /dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" > /dev/null
rm -rf "$WORK"
echo "Made $DMG"
