#!/usr/bin/env bash
# Builds the release binary and wraps it in RAMMenubar.app (menu bar only, no Dock icon).
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/RAMMenubar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BIN_DIR/RAMMenubar" "$APP/Contents/MacOS/RAMMenubar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RAMMenubar</string>
    <key>CFBundleDisplayName</key>
    <string>RAM Monitor</string>
    <key>CFBundleIdentifier</key>
    <string>local.my-menubar.ram-monitor</string>
    <key>CFBundleExecutable</key>
    <string>RAMMenubar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built $APP"
