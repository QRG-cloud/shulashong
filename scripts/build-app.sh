#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$PROJECT_DIR/dist"
APP_DIR="$BUILD_DIR/鼠拉松.app"
MODULE_CACHE="$PROJECT_DIR/.build/module-cache"
ICON_SOURCE="$PROJECT_DIR/Assets/ShuLaSong-AppIcon-1024.png"
ICONSET_DIR="$PROJECT_DIR/.build/ShuLaSong.iconset"
ICNS_FILE="$PROJECT_DIR/.build/ShuLaSong.icns"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-ShuLaSong Local Code Signing}"

cd "$PROJECT_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$MODULE_CACHE"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing icon source: $ICON_SOURCE" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
clang \
  -fobjc-arc \
  -fmodules \
  -fmodules-cache-path="$MODULE_CACHE" \
  -framework Foundation \
  "$PROJECT_DIR/scripts/IconPack.m" \
  -o "$PROJECT_DIR/.build/iconpack"
"$PROJECT_DIR/.build/iconpack" "$ICONSET_DIR" "$ICNS_FILE" >/dev/null

clang \
  -fobjc-arc \
  -fmodules \
  -fmodules-cache-path="$MODULE_CACHE" \
  -mmacosx-version-min=13.0 \
  -O2 \
  -framework Cocoa \
  -framework ApplicationServices \
  -framework UniformTypeIdentifiers \
  "$PROJECT_DIR/Sources/DayTrace/DayTrace.m" \
  -o "$APP_DIR/Contents/MacOS/DayTrace"

cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICNS_FILE" "$APP_DIR/Contents/Resources/ShuLaSong.icns"
chmod +x "$APP_DIR/Contents/MacOS/DayTrace"

"$APP_DIR/Contents/MacOS/DayTrace" --self-test

if security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --sign "$SIGNING_IDENTITY" \
    "$APP_DIR"
else
  echo "Signing identity '$SIGNING_IDENTITY' not found; using ad-hoc signing." >&2
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --sign - \
    "$APP_DIR"
fi
echo "$APP_DIR"
