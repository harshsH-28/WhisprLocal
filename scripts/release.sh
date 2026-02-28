#!/bin/bash
set -euo pipefail

# Build WhisprLocal and package into a DMG
# Usage: ./scripts/release.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building release app ==="
"$SCRIPT_DIR/build-app.sh" release

echo ""
echo "=== Packaging DMG ==="
"$SCRIPT_DIR/create-dmg.sh"

echo ""
echo "=== Release complete ==="
echo "Output: build/WhisprLocal.dmg"
