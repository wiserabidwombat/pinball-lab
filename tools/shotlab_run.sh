#!/bin/bash
# Pinball Lab · Shot Lab runner (macOS). Builds the app for the iOS Simulator, launches it with `-shotlab <table>` so the
# Shot Lab sweep runs unattended (every flip delay from each flipper, 120 Hz and 60 Hz passes), waits for it to quit,
# then prints the timing windows. Run from the project root in Terminal:
#
#   tools/shotlab_run.sh lamplight                        # the whole sweep (~40 min)
#   tools/shotlab_run.sh lamplight booksdown left,right   # bookshelf down (measures the fireplace), two flippers (~25 min)
#   SKIP_BUILD=1 tools/shotlab_run.sh lamplight           # reuse the last build
#
# Tables: lamplight (others as their views pick up `-shotlab`). Scenarios: lamplight: booksdown. Results go to ShotLab/.
set -euo pipefail
TABLE=${1:?table (lamplight)}
SCENARIO=${2:-}
FLIPPERS=${3:-}
DEVICE=${DEVICE:-iPhone 17 Pro Max}
BUNDLE=com.aarontilley.pinballlab
PROJECT=GreyInvasionPinball.xcodeproj
SCHEME=GreyInvasionPinball
cd "$(dirname "$0")/.."
DERIVED=build/playlab

echo "▶ Simulator: $DEVICE"
UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys; d=json.load(sys.stdin)
for devs in d['devices'].values():
    for x in devs:
        if x['name']=='$DEVICE': print(x['udid']); sys.exit()
print('')")
[ -n "$UDID" ] || { echo "No simulator named '$DEVICE' (set DEVICE=...)"; xcrun simctl list devices available | grep iPhone; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$UDID" || true

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "▶ Building (Debug, simulator)…"
  mkdir -p "$DERIVED"
  if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator \
      -destination "id=$UDID" -derivedDataPath "$DERIVED" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build > "$DERIVED/build.log" 2>&1; then
    grep -E "error:|BUILD FAILED" "$DERIVED/build.log" | head -20
    echo "Build failed (full log: $DERIVED/build.log)"; exit 1
  fi
  grep -E "warning:" "$DERIVED/build.log" | grep -v "appintentsmetadataprocessor" | head -10 || true
  echo "▶ Build OK"
fi
APP=$(find "$DERIVED/Build/Products" -name "*.app" -path "*iphonesimulator*" | head -1)
[ -n "$APP" ] || { echo "No .app built under $DERIVED"; exit 1; }

echo "▶ Installing $APP"
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

ARGS=(-shotlab "$TABLE")
[ -n "$SCENARIO" ] && ARGS+=(-shotlab-scenario "$SCENARIO")
[ -n "$FLIPPERS" ] && ARGS+=(-shotlab-flippers "$FLIPPERS")
echo "▶ Launching the Shot Lab: ${ARGS[*]} (the app quits by itself when the results are saved)"
BEFORE=$(ls -t ShotLab/shotlab-*.json 2>/dev/null | head -1 || true)
xcrun simctl launch --console "$UDID" "$BUNDLE" "${ARGS[@]}" | grep -E "SHOT LAB" || true

AFTER=$(ls -t ShotLab/shotlab-*.json 2>/dev/null | head -1 || true)
if [ -n "$AFTER" ] && [ "$AFTER" != "$BEFORE" ]; then
  echo "▶ Results: $AFTER"
  python3 tools/shotlab_windows.py "$AFTER"
else
  echo "No new results in ShotLab/ (did the app quit early? check the Simulator)."
fi
