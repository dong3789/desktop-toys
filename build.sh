#!/bin/bash
set -e; cd "$(dirname "$0")"
APP=${APP:-~/Applications/DesktopToys.app}
VER=$(cat VERSION); BUILDNO=$(( $(cat BUILD) + 1 )); echo $BUILDNO > BUILD
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/* "$APP/Contents/Resources/"
for A in arm64 x86_64; do swiftc -O -swift-version 5 -target $A-apple-macos13.0 Sources/*.swift -o /tmp/DesktopToys-$A; done
lipo -create /tmp/DesktopToys-arm64 /tmp/DesktopToys-x86_64 -output "$APP/Contents/MacOS/DesktopToys"
cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.yndl.desktop-toys</string><key>CFBundleName</key><string>DesktopToys</string><key>CFBundleExecutable</key><string>DesktopToys</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>$VER</string><key>CFBundleVersion</key><string>$BUILDNO</string><key>NSHumanReadableCopyright</key><string>DesktopToys</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>13.0</string></dict></plist>
P
codesign -s - --force "$APP" >/dev/null 2>&1 || true
echo built $APP v$VER build $BUILDNO
