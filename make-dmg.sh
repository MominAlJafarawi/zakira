#!/bin/zsh
# Builds the app, then packs it as dist/Zakira-<version>.dmg for sharing (USB stick, AirDrop, email).
set -e
cd "$(dirname "$0")"
./build.sh
VERSION=$(defaults read "$PWD/Info.plist" CFBundleShortVersionString)
STAGE="${TMPDIR:-/tmp}/zakira-build"
DMGROOT="$STAGE/dmg"
rm -rf "$DMGROOT"; mkdir -p "$DMGROOT"
ditto --norsrc "$STAGE/Zakira.app" "$DMGROOT/Zakira.app"
ln -s /Applications "$DMGROOT/Applications"
cp "Tools/Install - التثبيت.txt" "$DMGROOT/"
chmod 644 "$DMGROOT/"*.txt
rm -f "$STAGE/Zakira.dmg"
hdiutil create -volname "Zakira" -srcfolder "$DMGROOT" -ov -format UDZO "$STAGE/Zakira.dmg" >/dev/null
mkdir -p dist
cp "$STAGE/Zakira.dmg" "dist/Zakira-$VERSION.dmg"
find . -name "._*" -delete 2>/dev/null || true
echo "DMG: $PWD/dist/Zakira-$VERSION.dmg"
