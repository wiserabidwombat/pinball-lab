#!/bin/bash
# Pinball Lab · Play Lab runner (macOS). Builds the app for the iOS Simulator, launches it with `-playlab <table>` so the
# Play Lab runs unattended (robot players at four skills, 120 Hz and 60 Hz passes), waits for it to quit, then prints
# the report. Run from the project root in Terminal:
#
#   tools/playlab_run.sh lamplight                  # all skills, both passes, 2 games each (~1 h)
#   tools/playlab_run.sh lamplight 1 120            # 1 game per skill, 120 Hz only (~20 min)
#   tools/playlab_run.sh lamplight 2 both expert    # one skill
#   SKIP_BUILD=1 tools/playlab_run.sh lamplight     # reuse the last build
#
# Tables: lamplight (more as they adopt PlayLabHost: greyinvasion, cthulhu, monsoon). Reports go to ShotLab/.
set -euo pipefail
TABLE=${1:?table (lamplight, greyinvasion, cthulhu, monsoon)}
GAMES=${2:-2}
HZ=${3:-both}
SKILLS=${4:-}
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
# Simulator.app moves between Xcode versions: open it by bundle id.
open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$UDID" || true

if [ -z "${SKIP_BUILD:-}" ]; then
  echo "▶ Building (Debug, simulator)…"
  mkdir -p "$DERIVED"
  # No code signing for a simulator build (automatic signing otherwise fails at CodeSign); stop if it fails.
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

ARGS=(-playlab "$TABLE" -playlab-games "$GAMES" -playlab-hz "$HZ")
[ -n "$SKILLS" ] && ARGS+=(-playlab-skills "$SKILLS")
echo "▶ Launching the Play Lab: ${ARGS[*]} (the app quits by itself when the report is saved)"
BEFORE=$(ls -t ShotLab/playlab-*.json 2>/dev/null | head -1 || true)
# --console attaches to the app's stdout and returns when it exits.
xcrun simctl launch --console "$UDID" "$BUNDLE" "${ARGS[@]}" | grep -E "LAB:|PLAY LAB" || true

AFTER=$(ls -t ShotLab/playlab-*.json 2>/dev/null | head -1 || true)
if [ -n "$AFTER" ] && [ "$AFTER" != "$BEFORE" ]; then
  echo "▶ Report: $AFTER"
  STEM="${AFTER%.json}"
  # Shots meant to be hard on this table (an expert rate under 15% is noted, not flagged).
  case "$TABLE" in lamplight) PRECISE="mail";; *) PRECISE="";; esac
  python3 tools/playlab_report.py "$AFTER" --tracks "$STEM-tracks.svg" --html ${PRECISE:+--precise $PRECISE}
  echo "▶ Report page: $STEM.html (screenshots in $STEM/, tracks in $STEM-tracks.svg)"
  open "$STEM.html" 2>/dev/null || true
else
  echo "No new report in ShotLab/ (did the app quit early? check the Simulator)."
fi
