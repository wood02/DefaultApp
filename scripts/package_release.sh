#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$REPO_ROOT/Resources/Info.plist" 2>/dev/null || echo "0.0.2")
APP_NAME="Default App"
BUILD_APP="$REPO_ROOT/build/$APP_NAME.app"
DIST_DIR="$REPO_ROOT/dist"

# Build first
"$REPO_ROOT/scripts/build.sh"

echo "==> Packaging releases into $DIST_DIR..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/*

# 1. Package ZIP
ZIP_NAME="Default-App-v${VERSION}-macOS-Universal.zip"
echo "  -> Generating $ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$BUILD_APP" "$DIST_DIR/$ZIP_NAME"

# 2. Package DMG
DMG_NAME="Default-App-v${VERSION}-macOS-Universal.dmg"
echo "  -> Generating $DMG_NAME..."
DMG_TMP="/tmp/default_app_dmg"
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"

cp -R "$BUILD_APP" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TMP" -ov -format UDZO "$DIST_DIR/$DMG_NAME"
rm -rf "$DMG_TMP"

# 3. Generate SHA256 checksums
echo "  -> Generating SHA256 checksums..."
cd "$DIST_DIR"
shasum -a 256 *.zip *.dmg > checksums.txt

echo "==> Packaging complete! Artifacts in dist/:"
ls -lh "$DIST_DIR"
cat "$DIST_DIR/checksums.txt"
