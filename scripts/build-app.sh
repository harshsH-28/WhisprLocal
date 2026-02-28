#!/bin/bash
set -euo pipefail

# Build WhisprLocal.app bundle from SPM output
# Usage: ./scripts/build-app.sh [release|debug]
#
# Prerequisites:
#   - Swift 5.10+ toolchain (Xcode 15.3+ or Command Line Tools)
#   - For tests: Xcode must be installed (swift test requires XCTest framework)
#   - To run tests: xcode-select -s /Applications/Xcode.app/Contents/Developer && swift test

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_CONFIG="${1:-release}"

APP_NAME="WhisprLocal"
BUNDLE_ID="com.whisprlocal.app"
APP_DIR="$PROJECT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME ($BUILD_CONFIG)..."

# Build with SPM
cd "$PROJECT_DIR"
if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release
    BUILD_DIR=".build/release"
else
    swift build
    BUILD_DIR=".build/debug"
fi

# Create .app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Embed whisper.framework
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"
WHISPER_FW="$PROJECT_DIR/.build/artifacts/whisprlocal/whisper/whisper.xcframework/macos-arm64_x86_64/whisper.framework"
if [ -d "$WHISPER_FW" ]; then
    cp -R "$WHISPER_FW" "$FRAMEWORKS_DIR/"
    echo "Embedded whisper.framework"
else
    echo "ERROR: whisper.framework not found at $WHISPER_FW"
    exit 1
fi

# Fix rpath so the executable finds the embedded framework
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Create entitlements for ad-hoc signing
ENTITLEMENTS="$PROJECT_DIR/build/entitlements.plist"
cat > "$ENTITLEMENTS" << 'ENTITLEMENTS_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS_EOF

# Ad-hoc code sign
echo "Code signing..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR"

# Clear stale TCC entries so macOS re-prompts for the new binary
echo "Clearing stale TCC entries for $BUNDLE_ID..."
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true

echo ""
echo "Build complete: $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "Note: Permissions were reset during build. You'll be prompted to grant"
echo "Microphone and Accessibility permissions on next launch."
echo "Place your whisper model at:"
echo "  ~/Library/Application Support/WhisprLocal/models/ggml-base.bin"
