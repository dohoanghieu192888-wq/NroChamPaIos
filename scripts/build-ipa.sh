#!/usr/bin/env bash
#
# Build mot file .ipa KHONG KY (unsigned) tu project Unity export sang Xcode.
# Dung de sideload bang ESign / Sideloadly / AltStore / TrollStore.
#
# Yeu cau: chay tren macOS co Xcode (hoac GitHub Actions runner macos-*).
#   bash scripts/build-ipa.sh
#
# Bien moi truong co the ghi de:
#   SCHEME=Unity-iPhone  CONFIG=Release  APP_NAME=NroChamPa  IPA_NAME=out.ipa
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-Unity-iPhone.xcodeproj}"
SCHEME="${SCHEME:-Unity-iPhone}"
CONFIG="${CONFIG:-Release}"
APP_NAME="${APP_NAME:-NroChamPa}"
OUT_DIR="${OUT_DIR:-build}"
IPA_NAME="${IPA_NAME:-${APP_NAME}-unsigned.ipa}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "LOI: khong tim thay xcodebuild." >&2
  echo "Build .ipa bat buoc phai chay tren macOS co Xcode. Windows/Linux khong the build." >&2
  exit 1
fi

[ -d "$PROJECT" ] || { echo "LOI: khong thay $PROJECT (hay chay script tu thu muc goc project)." >&2; exit 1; }

echo "==> Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "==> Build unsigned: scheme=$SCHEME config=$CONFIG"

rm -rf "$OUT_DIR/DerivedData"
mkdir -p "$OUT_DIR"

# Tat toan bo code signing de khong can Apple Developer account / certificate.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -derivedDataPath "$OUT_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  build

APP_PATH="$OUT_DIR/DerivedData/Build/Products/${CONFIG}-iphoneos/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "LOI: khong thay app bundle tai: $APP_PATH" >&2
  echo "Cac thu muc co trong Products:" >&2
  ls -la "$OUT_DIR/DerivedData/Build/Products" 2>/dev/null >&2 || true
  exit 1
fi

# Verify: phai la app iOS that su (co Info.plist + binary), khong phai thu muc rong.
[ -f "$APP_PATH/Info.plist" ] || { echo "LOI: $APP_PATH thieu Info.plist" >&2; exit 1; }
EXEC_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist" 2>/dev/null || echo "$APP_NAME")"
[ -f "$APP_PATH/$EXEC_NAME" ] || { echo "LOI: $APP_PATH thieu binary '$EXEC_NAME'" >&2; exit 1; }
[ -d "$APP_PATH/Data" ] || echo "CANH BAO: $APP_PATH/Data khong ton tai - kiem tra buoc copy Data cua Unity."

# Dong goi: Payload/<App>.app -> zip -> .ipa
rm -rf "$OUT_DIR/Payload" "$OUT_DIR/$IPA_NAME"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP_PATH" "$OUT_DIR/Payload/"
( cd "$OUT_DIR" && zip -qry "$IPA_NAME" Payload )
rm -rf "$OUT_DIR/Payload"

# Verify ket qua
SIZE="$(du -h "$OUT_DIR/$IPA_NAME" | cut -f1)"
unzip -l "$OUT_DIR/$IPA_NAME" | grep -q "Payload/${APP_NAME}.app/Info.plist" \
  || { echo "LOI: IPA khong chua Payload/${APP_NAME}.app" >&2; exit 1; }

echo "==> XONG: $OUT_DIR/$IPA_NAME ($SIZE, unsigned)"
echo "    Cai bang: ESign / Sideloadly / AltStore / TrollStore (tu ky lai khi cai)."
