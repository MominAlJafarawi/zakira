#!/bin/zsh
# Builds "ذاكرة الكتابة" into build/Zakira.app
set -e
cd "$(dirname "$0")"
STAGE="${TMPDIR:-/tmp}/zakira-build"
APP="$STAGE/Zakira.app"
rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/tmp

# Universal: runs on Apple Silicon and Intel Macs.
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $ARCH-apple-macos14.0 Sources/*.swift -o "$STAGE/Zakira-$ARCH"
done
lipo -create "$STAGE/Zakira-arm64" "$STAGE/Zakira-x86_64" -output "$APP/Contents/MacOS/Zakira"

# icon
if [ ! -f build/tmp/AppIcon.icns ]; then
  swiftc -swift-version 5 Tools/MakeIcon.swift -o build/tmp/makeicon
  build/tmp/makeicon build/tmp/icon1024.png
  ICONSET=build/tmp/AppIcon.iconset; mkdir -p $ICONSET
  for s in 16 32 128 256 512; do
    sips -z $s $s build/tmp/icon1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) build/tmp/icon1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $ICONSET -o build/tmp/AppIcon.icns
fi
cp build/tmp/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
cp -R Resources/en.lproj Resources/ar.lproj "$APP/Contents/Resources/"
xattr -cr "$APP"
# Sign with the personal certificate when it exists: the permission then stays after updates
# and no other program can pretend to be Zakira.
IDENTITY="Zakira Code Signing"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "Signed with personal certificate"
else
  echo "WARNING: certificate \"$IDENTITY\" not found, using weaker ad-hoc signature"
  codesign --force --sign - -r='designated => identifier "com.momen.zakira"' "$APP"
fi
DEST=/Applications/Zakira.app
rm -rf "$DEST"
ditto --norsrc "$APP" "$DEST"
codesign --verify --verbose "$DEST"
echo "Installed to $DEST"
