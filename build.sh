#!/bin/bash
# Builds XMac and packages it as X.app.
#
#   ./build.sh          # release build
#   ./build.sh --run    # build and launch
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="X"
EXE_NAME="XMac"
VERSION="1.0.0"
BUILD_NUMBER="1"
RUN=0
if [[ "${1:-}" == "--run" ]]; then
  RUN=1
fi

echo "=== Building $EXE_NAME $VERSION ==="
swift build -c release

BIN="$(swift build -c release --show-bin-path)/$EXE_NAME"
if [[ ! -x "$BIN" ]]; then
  echo "Binary missing: $BIN" >&2
  exit 1
fi

ICON_SRC="Resources/AppIcon.icns"
if [[ ! -f "$ICON_SRC" && -f scripts/make-icon.swift ]]; then
  echo "=== Drawing app icon ==="
  mkdir -p Resources
  swiftc scripts/make-icon.swift -framework AppKit -framework CoreGraphics -o /tmp/xmac-make-icon
  /tmp/xmac-make-icon "$PWD/$ICON_SRC"
fi

echo "=== Packaging $APP_NAME.app ==="
APP="$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXE_NAME"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$EXE_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>app.p2plus.xmac</string>
	<key>CFBundleName</key>
	<string>X</string>
	<key>CFBundleDisplayName</key>
	<string>X</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.social-networking</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
	<key>NSCameraUsageDescription</key>
	<string>Used when you take a photo or start a video on X.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Used when you record audio on X.</string>
	<key>NSHumanReadableCopyright</key>
	<string>Unofficial client. Not affiliated with X Corp.</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>app.p2plus.xmac</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>xmac</string>
				<string>twitter</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"

echo "=== Ad-hoc signature ==="
codesign --force --sign - --entitlements Entitlements.plist "$APP"
codesign --verify --verbose=2 "$APP"

echo "=== Done ==="
echo "App: $PWD/$APP"
if [[ "$RUN" -eq 1 ]]; then
  open "$PWD/$APP"
fi
