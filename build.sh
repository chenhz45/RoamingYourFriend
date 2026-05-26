#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="RoamingYourFriend"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== Building $APP_NAME ==="

# Build with SPM
echo "→ Compiling..."
swift build -c release --package-path "$PROJECT_DIR"

# Create .app bundle
echo "→ Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Copy binary
cp "$PROJECT_DIR/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy face processing resources into bundle
mkdir -p "$APP_BUNDLE/Contents/Resources"

FACE_CROP_BIN="$PROJECT_DIR/PythonScripts/dist/face_crop"
if [ -f "$FACE_CROP_BIN" ]; then
    # Standalone binary (zero dependencies for end users)
    cp "$FACE_CROP_BIN" "$APP_BUNDLE/Contents/Resources/"
    echo "→ Bundled standalone face_crop binary"
else
    # Fallback: bundle Python script + model (requires python3 + mediapipe + pillow)
    mkdir -p "$APP_BUNDLE/Contents/Resources/PythonScripts"
    cp "$PROJECT_DIR/PythonScripts/face_crop.py" "$APP_BUNDLE/Contents/Resources/PythonScripts/"
    cp "$PROJECT_DIR/PythonScripts/blaze_face_short_range.tflite" "$APP_BUNDLE/Contents/Resources/PythonScripts/"
    echo "→ Bundled Python script (python3 + mediapipe + pillow required)"
fi

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RoamingYourFriend</string>
    <key>CFBundleIdentifier</key>
    <string>com.roamingyourfriend.app</string>
    <key>CFBundleName</key>
    <string>RoamingYourFriend</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "✓ Done: $APP_BUNDLE"
echo "Run: open '$APP_BUNDLE'"
