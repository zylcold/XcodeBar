#!/usr/bin/env bash
set -euo pipefail

APP_NAME="XcodeBar"
APP_DISPLAY_NAME="MenuBar for Xcode"
BUNDLE_ID="com.yunlongzhu.menubarforxcode"
VERSION="${1:-dev}"
BUNDLE_VERSION="${VERSION#v}"
if [[ ! "$BUNDLE_VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    BUNDLE_VERSION="0.0.0"
fi
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/MenuBar-for-Xcode-$VERSION.dmg"
ENTITLEMENTS="$ROOT_DIR/XcodeBar/XcodeBar.entitlements"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xcodebar-package.XXXXXX")"
APP_BUNDLE="$STAGING_DIR/$APP_DISPLAY_NAME.app"
STAGED_DMG_PATH="$STAGING_DIR/MenuBar-for-Xcode-$VERSION.dmg"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swift build -c release --product "$APP_NAME"

/bin/cp -X "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUNDLE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

find "$APP_BUNDLE" -exec xattr -c {} \; 2>/dev/null || true
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

hdiutil create \
    -volname "$APP_DISPLAY_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov \
    -format UDZO \
    "$STAGED_DMG_PATH"

/bin/cp -X "$STAGED_DMG_PATH" "$DMG_PATH"

echo "$DMG_PATH"
