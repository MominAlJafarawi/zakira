#!/bin/zsh
# Renders docs/screenshots/*.png with demo text only (ZAKIRA_DEMO keeps the real Keychain untouched).
set -e
cd "$(dirname "$0")/.."
T="${TMPDIR:-/tmp}/zakira-shots"; rm -rf "$T"; mkdir -p "$T"
cp Sources/*.swift "$T/"; rm "$T/main.swift"; cp Tools/DemoShots/main.swift "$T/main.swift"
swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.0" "$T"/*.swift -o "$T/demoshots"
mkdir -p docs/screenshots
ZAKIRA_DEMO=1 "$T/demoshots" "$PWD/docs/screenshots" "$T"
find . -name "._*" -delete 2>/dev/null || true
ls docs/screenshots
