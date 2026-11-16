#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/DisplayScale.app"
PANE="$BUILD_DIR/DisplayScale.prefPane"
OUTPUT_PKG="$BUILD_DIR/DisplayScale.pkg"
PANE_SOURCE="$ROOT/Sources/DisplayScalePrefPane"
APP_SIGNING_IDENTITY="${DISPLAY_SCALE_APP_SIGNING_IDENTITY:--}"
INSTALLER_SIGNING_IDENTITY="${DISPLAY_SCALE_INSTALLER_SIGNING_IDENTITY:-}"
INCLUDE_PREFPANE=1

for argument in "$@"; do
  case "$argument" in
    --without-prefpane|--no-prefpane)
      INCLUDE_PREFPANE=0
      ;;
    --with-prefpane|--include-prefpane)
      INCLUDE_PREFPANE=1
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./build.sh [--without-prefpane]

By default, creates build/DisplayScale.pkg with the app and preference pane.
Use --without-prefpane to create an app-only installer package.
USAGE
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$argument" >&2
      printf 'Run ./build.sh --help for usage.\n' >&2
      exit 2
      ;;
  esac
done

mkdir -p "$BUILD_DIR"
PACKAGE_ROOT="$(mktemp -d "$BUILD_DIR/DisplayScale-package-root.XXXXXX")"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT

"$ROOT/build-app.sh"

mkdir -p "$PACKAGE_ROOT/Applications"
ditto --norsrc "$APP" "$PACKAGE_ROOT/Applications/DisplayScale.app"

if [ "$INCLUDE_PREFPANE" -eq 1 ]; then
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
  mkdir -p "$PANE/Contents/MacOS"
  cp "$PANE_SOURCE/Info.plist" "$PANE/Contents/Info.plist"
  swiftc \
    -sdk "$SDK_PATH" \
    -target "$(uname -m)-apple-macosx13.0" \
    -swift-version 5 \
    -module-name DisplayScalePrefPane \
    -emit-library \
    -Xlinker -bundle \
    -framework AppKit \
    -framework PreferencePanes \
    -framework SwiftUI \
    -framework IOKit \
    "$ROOT/Sources/DisplayScaleApp/ContentView.swift" \
    "$ROOT/Sources/DisplayScaleApp/DisplayInfo.swift" \
    "$ROOT/Sources/DisplayScaleApp/DisplayModeManager.swift" \
    "$ROOT/Sources/DisplayScaleApp/DisplayScaleViewModel.swift" \
    "$PANE_SOURCE/DisplayScalePrefPane.swift" \
    -o "$PANE/Contents/MacOS/DisplayScalePrefPane"
  if [ "$APP_SIGNING_IDENTITY" = "-" ]; then
    codesign --force --sign - "$PANE"
  else
    codesign --force --timestamp --options runtime --sign "$APP_SIGNING_IDENTITY" "$PANE"
  fi
  codesign --verify --strict "$PANE"
  plutil -lint "$PANE/Contents/Info.plist"
  mkdir -p "$PACKAGE_ROOT/Library/PreferencePanes"
  ditto --norsrc "$PANE" "$PACKAGE_ROOT/Library/PreferencePanes/DisplayScale.prefPane"
else
  rm -rf "$PANE"
fi
codesign --verify --deep --strict "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
rm -f "$OUTPUT_PKG"
PKGBUILD_ARGS=(
  --root "$PACKAGE_ROOT"
  --identifier com.bonfales.displayscale.installer
  --version "$VERSION"
  --install-location /
  --ownership recommended
)
if [ -n "$INSTALLER_SIGNING_IDENTITY" ]; then
  pkgbuild "${PKGBUILD_ARGS[@]}" --sign "$INSTALLER_SIGNING_IDENTITY" --timestamp "$OUTPUT_PKG"
else
  pkgbuild "${PKGBUILD_ARGS[@]}" "$OUTPUT_PKG"
fi

if [ "$INCLUDE_PREFPANE" -eq 1 ]; then
  printf 'Created installer (app + preference pane): %s\n' "$OUTPUT_PKG"
else
  printf 'Created installer (app only): %s\n' "$OUTPUT_PKG"
fi
