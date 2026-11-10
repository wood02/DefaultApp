#!/usr/bin/env bash
set -e

# Project root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Default App"
BUNDLE_DIR="$REPO_ROOT/build/$APP_NAME.app"
TMP_DIR="/tmp/default_app_build"

echo "==> Building $APP_NAME (Universal Binary: arm64 + x86_64)..."

mkdir -p "$TMP_DIR"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# 1. Compile arm64
echo "  -> Compiling arm64..."
swiftc -parse-as-library -O \
    -target arm64-apple-macos12.0 \
    -o "$TMP_DIR/DefaultApp_arm64" \
    "$REPO_ROOT/Sources/main.swift"

# 2. Compile x86_64
echo "  -> Compiling x86_64..."
swiftc -parse-as-library -O \
    -target x86_64-apple-macos12.0 \
    -o "$TMP_DIR/DefaultApp_x86_64" \
    "$REPO_ROOT/Sources/main.swift"

# 3. Create Universal Binary
echo "  -> Creating Universal Binary with lipo..."
lipo -create \
    "$TMP_DIR/DefaultApp_arm64" \
    "$TMP_DIR/DefaultApp_x86_64" \
    -output "$BUNDLE_DIR/Contents/MacOS/DefaultApp"

chmod +x "$BUNDLE_DIR/Contents/MacOS/DefaultApp"

# 4. Copy Resources
echo "  -> Copying Info.plist and AppIcon.icns..."
cp "$REPO_ROOT/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
cp "$REPO_ROOT/Resources/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"

# 5. Codesign (Ad-hoc)
echo "  -> Signing bundle..."
codesign -fs - --deep "$BUNDLE_DIR"

# 6. Clear quarantine / xattr
xattr -c -r "$BUNDLE_DIR" 2>/dev/null || true

echo "==> Successfully built: $BUNDLE_DIR"
file "$BUNDLE_DIR/Contents/MacOS/DefaultApp"
