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
mkdir -p "$BUILD_DIR"
PACKAGE_WORK="$(mktemp -d "$BUILD_DIR/DisplayScale-package.XXXXXX")"
trap 'rm -rf "$PACKAGE_WORK"' EXIT

"$ROOT/build-app.sh"

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
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$PANE"
plutil -lint "$PANE/Contents/Info.plist"

APP_ROOT="$PACKAGE_WORK/app-root"
PANE_ROOT="$PACKAGE_WORK/pane-root"
COMPONENTS_DIR="$PACKAGE_WORK/components"
mkdir -p "$APP_ROOT/Applications" "$PANE_ROOT/Library/PreferencePanes" "$COMPONENTS_DIR"
ditto --norsrc "$APP" "$APP_ROOT/Applications/DisplayScale.app"
ditto --norsrc "$PANE" "$PANE_ROOT/Library/PreferencePanes/DisplayScale.prefPane"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
APP_COMPONENT="$COMPONENTS_DIR/DisplayScale-app.pkg"
PANE_COMPONENT="$COMPONENTS_DIR/DisplayScale-prefpane.pkg"
pkgbuild \
  --root "$APP_ROOT" \
  --identifier com.bonfales.displayscale.app \
  --version "$VERSION" \
  --install-location / \
  --ownership recommended \
  "$APP_COMPONENT"
pkgbuild \
  --root "$PANE_ROOT" \
  --identifier com.bonfales.displayscale.prefpane \
  --version "$VERSION" \
  --install-location / \
  --ownership recommended \
  "$PANE_COMPONENT"

DISTRIBUTION="$PACKAGE_WORK/Distribution.xml"
sed "s/@VERSION@/$VERSION/g" "$ROOT/Installer/Distribution.xml" > "$DISTRIBUTION"
xmllint --noout "$DISTRIBUTION"
rm -f "$OUTPUT_PKG"
PRODUCTBUILD_ARGS=(
  --distribution "$DISTRIBUTION"
  --package-path "$COMPONENTS_DIR"
  --identifier com.bonfales.displayscale.installer
)
if [ -n "$INSTALLER_SIGNING_IDENTITY" ]; then
  productbuild "${PRODUCTBUILD_ARGS[@]}" --sign "$INSTALLER_SIGNING_IDENTITY" --timestamp "$OUTPUT_PKG"
else
  productbuild "${PRODUCTBUILD_ARGS[@]}" "$OUTPUT_PKG"
fi

printf 'Created installer: %s\n' "$OUTPUT_PKG"
