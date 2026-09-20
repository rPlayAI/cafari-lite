#!/bin/bash
# Build, sign and install on a connected iPhone without opening Xcode.
#
#   tools/run-on-device.sh                  # values from Local.xcconfig
#   BUNDLE_ID=com.you.lite TEAM=ABCDE12345 tools/run-on-device.sh
#   DEVICE=<udid> tools/run-on-device.sh    # when more than one is attached
#
# CarPlay needs a real device: the entitlements cannot be embedded in a
# Simulator build, so there is nothing to test there.

set -euo pipefail
cd "$(dirname "$0")/.."

read_config() {  # read_config KEY -> value from Local.xcconfig, or empty
  [ -f Local.xcconfig ] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" Local.xcconfig | tail -1 \
    | sed 's/[[:space:]]*$//'
}

BUNDLE_ID="${BUNDLE_ID:-$(read_config CAFARI_LITE_BUNDLE_ID)}"
TEAM="${TEAM:-$(read_config CAFARI_LITE_TEAM)}"
ENTITLEMENTS="${ENTITLEMENTS:-$(read_config CAFARI_LITE_ENTITLEMENTS)}"

if [ -z "$BUNDLE_ID" ] || [ -z "$TEAM" ]; then
  echo "Set CAFARI_LITE_BUNDLE_ID and CAFARI_LITE_TEAM in Local.xcconfig" >&2
  echo "(copy Local.xcconfig.example), or pass BUNDLE_ID= and TEAM= here." >&2
  exit 1
fi

if [ -z "${DEVICE:-}" ]; then
  # The first paired, available, physical device.
  DEVICE=$(xcrun devicectl list devices 2>/dev/null \
    | grep physical | grep available \
    | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
    | head -1)
fi
if [ -z "$DEVICE" ]; then
  echo "No device found. Attach an unlocked iPhone, or pass DEVICE=<udid>." >&2
  exit 1
fi

OUT="$PWD/build/device"
echo "Building $BUNDLE_ID for $DEVICE"
xcodebuild -project CafariLite.xcodeproj -target CafariLite \
  -configuration Debug -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  CONFIGURATION_BUILD_DIR="$OUT" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
  build | grep -E "error:|warning: .*entitlement|BUILD (SUCCEEDED|FAILED)" || true

[ -d "$OUT/CafariLite.app" ] || { echo "Build produced no app." >&2; exit 1; }

echo "Installing"
xcrun devicectl device install app --device "$DEVICE" "$OUT/CafariLite.app"

echo
echo "Installed as Cafari Lite. Entitlements in the signed app:"
codesign -d --entitlements - --xml "$OUT/CafariLite.app" 2>/dev/null \
  | plutil -convert json -o - - 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  " + ("\n  ".join(sorted(k for k in d if "carplay" in k)) or "none -- phone only"))' 2>/dev/null || true
