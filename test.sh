#!/bin/zsh
# Runs Zakira's self-tests. Uses a separate test Keychain service; your real data is never touched.
set -e
cd "$(dirname "$0")"
T="${TMPDIR:-/tmp}/zakira-tests"; rm -rf "$T"; mkdir -p "$T"
cp Sources/*.swift "$T/"; rm "$T/main.swift"; cp Tests/main.swift "$T/main.swift"
swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.0" "$T"/*.swift -o "$T/zakira-tests"
ZAKIRA_DEMO=1 ZAKIRA_TEST_LAYOUT=com.apple.keylayout.US "$T/zakira-tests"
