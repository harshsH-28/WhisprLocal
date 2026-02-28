#!/bin/bash
set -euo pipefail

# Package WhisprLocal.app into a DMG installer
# Usage: ./scripts/create-dmg.sh
#
# Expects build/WhisprLocal.app to already exist (run build-app.sh first).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

APP_NAME="WhisprLocal"
APP_DIR="$PROJECT_DIR/build/${APP_NAME}.app"
DMG_PATH="$PROJECT_DIR/build/${APP_NAME}.dmg"

# Verify the .app exists
if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: $APP_DIR not found."
    echo "Run ./scripts/build-app.sh release first."
    exit 1
fi

echo "Creating DMG..."

# Clean up any previous DMG
rm -f "$DMG_PATH"

# Create a temporary staging directory
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

# Copy app and create Applications symlink
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "DMG created: $DMG_PATH"
