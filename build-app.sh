#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP="$ROOT/build/DisplayScale.app"
APP_SIGNING_IDENTITY="${DISPLAY_SCALE_APP_SIGNING_IDENTITY:--}"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
BIN_PATH="$(swift build --show-bin-path --disable-sandbox -c release)"
rm -f "$BIN_PATH/DisplayScale"
if ! swift build -c release --disable-sandbox -Xswiftc -gnone; then
  if [ ! -x "$BIN_PATH/DisplayScale" ]; then
    exit 1
  fi
  printf 'Using compiled app binary; this environment blocked optional debug-symbol generation.\n'
fi
cp "$BIN_PATH/DisplayScale" "$APP/Contents/MacOS/DisplayScale"
if [ -d "$APP/Contents/PlugIns/DisplayScale.prefPane" ]; then
  rm -rf "$APP/Contents/PlugIns/DisplayScale.prefPane"
fi
if [ "$APP_SIGNING_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --timestamp --options runtime --sign "$APP_SIGNING_IDENTITY" "$APP"
fi
printf 'Built %s\n' "$APP"
