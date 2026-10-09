
#!/usr/bin/env bash
#
# Build unsigned IPA from a Unity-exported Xcode project.
# Run on macOS with Xcode, such as GitHub Actions macos-14.
#
# Usage:
#   bash scripts/build-ipa.sh
#
# Optional environment variables:
#   PROJECT=Unity-iPhone.xcodeproj
#   SCHEME=Unity-iPhone
#   CONFIG=Release
#   APP_NAME=NroChamPa
#   IPA_NAME=NroChamPa.ipa
#   OUT_DIR=build
#

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-Unity-iPhone.xcodeproj}"
SCHEME="${SCHEME:-Unity-iPhone}"
CONFIG="${CONFIG:-Release}"
APP_NAME="${APP_NAME:-NroChamPa}"
OUT_DIR="${OUT_DIR:-build}"
IPA_NAME="${IPA_NAME:-NroChamPa.ipa}"

# Print the failing command and line number.
trap 'status=$?; echo "ERROR: Build failed at line ${LINENO} (exit ${status})." >&2; exit "$status"' ERR

echo "========================================"
echo " NroChamPa - Unsigned iOS IPA Builder"
echo "========================================"
echo "Project: $PROJECT"
echo "Scheme:  $SCHEME"
echo "Config:  $CONFIG"
echo "App:     $APP_NAME"
echo "Output:  $OUT_DIR/$IPA_NAME"
echo

# This script requires macOS and Xcode.
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: iOS IPA builds require macOS with Xcode."
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "ERROR: xcodebuild was not found."
    exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
    echo "ERROR: Xcode project not found: $PROJECT"
    echo "Files in project root:"
    ls -la
    exit 1
fi

echo "=== Xcode version ==="
xcodebuild -version

echo
echo "=== Validate project and scheme ==="
xcodebuild -list -project "$PROJECT"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/DerivedData"
mkdir -p "$OUT_DIR/DerivedData"

echo
echo "=== Build unsigned iOS app ==="

set +e
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$OUT_DIR/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    build
BUILD_STATUS=$?
set -e

if [[ "$BUILD_STATUS" -ne 0 ]]; then
    echo
    echo "ERROR: Xcode build failed with exit code $BUILD_STATUS."
    echo "Review the linker/compiler errors above."
    echo "Common causes include missing or invalid Unity libraries."
    exit "$BUILD_STATUS"
fi

PRODUCTS_DIR="$OUT_DIR/DerivedData/Build/Products"
APP_PATH="$PRODUCTS_DIR/${CONFIG}-iphoneos/${APP_NAME}.app"

# If APP_NAME differs from the actual product name, locate the built app.
if [[ ! -d "$APP_PATH" ]]; then
    echo "WARNING: Expected app not found at:"
    echo "  $APP_PATH"
    echo "Searching build products for .app bundles..."

    FOUND_APP=""
    while IFS= read -r -d '' candidate; do
        FOUND_APP="$candidate"
        break
    done < <(find "$PRODUCTS_DIR" -type d -name '*.app' -print0 2>/dev/null)

    if [[ -z "$FOUND_APP" ]]; then
        echo "ERROR: No .app bundle was produced."
        echo "Available build products:"
        find "$PRODUCTS_DIR" -maxdepth 4 -print 2>/dev/null || true
        exit 1
    fi

    APP_PATH="$FOUND_APP"
    echo "Using app bundle: $APP_PATH"
fi

echo
echo "=== Verify app bundle ==="

if [[ ! -f "$APP_PATH/Info.plist" ]]; then
    echo "ERROR: Info.plist is missing from $APP_PATH"
    exit 1
fi

EXEC_NAME=$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleExecutable' \
        "$APP_PATH/Info.plist" 2>/dev/null || true
)

if [[ -z "$EXEC_NAME" || ! -f "$APP_PATH/$EXEC_NAME" ]]; then
    echo "ERROR: App executable is missing."
    echo "Expected executable: $EXEC_NAME"
    exit 1
fi

if [[ ! -d "$APP_PATH/Data" ]]; then
    echo "WARNING: App bundle has no Data directory."
    echo "Check whether Unity data was copied into the app."
fi

# Prepare the IPA package.
PACKAGE_DIR="$OUT_DIR/ipa-package"
IPA_PATH="$OUT_DIR/$IPA_NAME"

rm -rf "$PACKAGE_DIR" "$IPA_PATH"
mkdir -p "$PACKAGE_DIR/Payload"

echo
echo "=== Package IPA ==="
cp -R "$APP_PATH" "$PACKAGE_DIR/Payload/"

(
    cd "$PACKAGE_DIR"
    /usr/bin/zip -qry "$ROOT/$IPA_PATH" Payload
)

rm -rf "$PACKAGE_DIR"

echo
echo "=== Verify IPA archive ==="

if [[ ! -s "$IPA_PATH" ]]; then
    echo "ERROR: IPA file was not created or is empty."
    exit 1
fi

if ! /usr/bin/unzip -t "$IPA_PATH"; then
    echo "ERROR: IPA archive validation failed."
    exit 1
fi

APP_BASENAME="$(basename "$APP_PATH")"

if ! /usr/bin/unzip -Z1 "$IPA_PATH" |
    grep -Fq "Payload/${APP_BASENAME}/Info.plist"; then
    echo "ERROR: IPA does not contain Payload/${APP_BASENAME}/Info.plist"
    exit 1
fi

echo
echo "========================================"
echo " SUCCESS: Unsigned IPA created"
echo " File: $IPA_PATH"
echo " Size: $(du -h "$IPA_PATH" | awk '{print $1}')"
echo "========================================"
echo "Note: Unsigned IPA may need signing before installation."
