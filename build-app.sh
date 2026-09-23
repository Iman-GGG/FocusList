#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

mkdir -p "$SCRIPT_DIR/.build/cache/clang" "$SCRIPT_DIR/.build/config" "$SCRIPT_DIR/.build/security"
CLANG_MODULE_CACHE_PATH="$SCRIPT_DIR/.build/cache/clang" swift build -c release \
  --scratch-path "$SCRIPT_DIR/.build" \
  --cache-path "$SCRIPT_DIR/.build/cache" \
  --config-path "$SCRIPT_DIR/.build/config" \
  --security-path "$SCRIPT_DIR/.build/security"

APP_DIR="$SCRIPT_DIR/dist/FocusList.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$SCRIPT_DIR/.build/release/FocusList" "$MACOS_DIR/FocusList"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$SCRIPT_DIR/Resources/AppIconSource.png" "$RESOURCES_DIR/AppIconSource.png"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
