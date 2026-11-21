#!/bin/bash
# Pinball Lab · Shot Lab runner (macOS). Builds the app for the iOS Simulator, launches it with `-shotlab <table>` so the
# Shot Lab sweep runs unattended (every flip delay from each flipper, 120 Hz and 60 Hz passes), waits for it to quit,
# then prints the timing windows. Run from the project root in Terminal:
#
#   tools/shotlab_run.sh lamplight                        # the whole sweep (~40 min)
#   tools/shotlab_run.sh lamplight booksdown left,right   # bookshelf down (measures the fireplace), two flippers (~25 min)
#   SKIP_BUILD=1 tools/shotlab_run.sh lamplight           # reuse the last build
#   tools/shotlab_run.sh cthulhu "" "" inlane             # plan 2 round 15: start from the inlane (or: drop); or START=inlane
#   tools/shotlab_run.sh chomp "" "" scatter              # the stuck-ball finder: random drops all over (DROPS=150 per pass)
#
# Tables: lamplight, cthulhu, monsoon, greyinvasion. Scenarios (2nd argument): lamplight booksdown, catmantel,
# catkettle · cthulhu cthulhuup,
# sigilsdown, ritual ·
# monsoon devilraging · greyinvasion bankdown (plan 2 round 16). Results go to ShotLab/.
set -euo pipefail
TABLE=${1:?table (lamplight)}
SCENARIO=${2:-}
FLIPPERS=${3:-}
START=${4:-${START:-}}
DEVICE=${DEVICE:-iPhone 18 Pro Max}
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
[ -n "$START" ] && ARGS+=(-shotlab-start "$START")
[ -n "${DROPS:-}" ] && ARGS+=(-shotlab-drops "$DROPS")
# 2026-11-21: 120 Hz only by default; HZ=60 or HZ=both for the old 60 Hz pass.
[ -n "${HZ:-}" ] && ARGS+=(-shotlab-hz "$HZ")
# Plan 2 round 18: OVERRIDE="Mon.ragingPush=2000,Mon.calmBend=0.0009" — what-if tunables (GreyInvasionPinball/LabOverrides.swift).
[ -n "${OVERRIDE:-}" ] && ARGS+=(-override "$OVERRIDE") && echo "▶ Overrides: $OVERRIDE"
# Lab fast-forward: FAST=8 → 8 fixed 1/120 s updates per drawn frame (4× real time; no screenshots in this mode).
[ -n "${FAST:-}" ] && ARGS+=(-lab-fast "$FAST") && echo "▶ Fast-forward: $FAST steps per frame"
echo "▶ Launching the Shot Lab: ${ARGS[*]} (the app quits by itself when the results are saved)"
BEFORE=$(ls -t ShotLab/shotlab-*.json 2>/dev/null | head -1 || true)
xcrun simctl launch --console "$UDID" "$BUNDLE" "${ARGS[@]}" | grep -E "SHOT LAB" || true

AFTER=$(ls -t ShotLab/shotlab-*.json 2>/dev/null | head -1 || true)
if [ -n "$AFTER" ] && [ "$AFTER" != "$BEFORE" ]; then
  echo "▶ Results: $AFTER"
  case "$AFTER" in
    *-scatter-*) python3 tools/shotlab_stuck.py "$AFTER" ;;     # the stuck-ball finder: its own report + map
    *) python3 tools/shotlab_windows.py "$AFTER" ;;
  esac
else
  echo "No new results in ShotLab/ (did the app quit early? check the Simulator)."
fi
