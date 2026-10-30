#!/bin/bash
# Pinball Lab · Play Lab runner (macOS). Builds the app for the iOS Simulator, launches it with `-playlab <table>` so the
# Play Lab runs unattended (robot players at four skills, 120 Hz and 60 Hz passes), waits for it to quit, then prints
# the report. Run from the project root in Terminal:
#
#   tools/playlab_run.sh lamplight                  # all skills, both passes, 2 games each (~1 h)
#   tools/playlab_run.sh lamplight 1 120            # 1 game per skill, 120 Hz only (~20 min)
#   tools/playlab_run.sh lamplight 2 both expert    # one skill
#   SKIP_BUILD=1 tools/playlab_run.sh lamplight     # reuse the last build
#   tools/playlab_run.sh monsoon plunge [hz]        # plan 2 round 7a: the plunge sweep (33 powers × 2 balls per pass)
#   BUILD_ONLY=1 tools/playlab_run.sh lamplight     # build (and write the build id), then stop — the sweep uses this
#   DEVICE="iPhone 17 Pro Max · lab 2" tools/playlab_run.sh …   # another Simulator device (the sweep's --parallel clones)
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
# 2026-10-29: a launch on a Simulator that is already up can stall for the whole budget (app up, "no drawables",
# the lab never starting); a launch on a freshly booted one hasn't yet. So shut it down first (FRESH_BOOT=0 to skip).
if [ "${FRESH_BOOT:-1}" != "0" ]; then
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  sleep 5
fi
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
  # Plan 2 round 1: remember what was built, so every report names its commit (and whether the tree was dirty).
  DIRTY=$(git status --porcelain --untracked-files=no 2>/dev/null | awk '{print $2}' | xargs -n1 basename 2>/dev/null | tr '\n' ',' | sed 's/,$//' || true)
  if [ -n "$DIRTY" ]; then DIRTY="dirty: $DIRTY"; else DIRTY=clean; fi
  printf '%s · %s · %s · %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo nogit)" \
    "$DIRTY" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')" \
    "$(date '+%Y-%m-%d %H:%M')" > "$DERIVED/build-id.txt"
fi
BUILD_ID=$(cat "$DERIVED/build-id.txt" 2>/dev/null || echo "unknown build")
if [ -n "${SKIP_BUILD:-}" ]; then
  HEAD_NOW=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
  case "$BUILD_ID" in "$HEAD_NOW"*) ;; *) BUILD_ID="$BUILD_ID · REUSED (HEAD now $HEAD_NOW)";; esac
fi
echo "▶ Build id: $BUILD_ID"
if [ -n "${BUILD_ONLY:-}" ]; then
  echo "▶ Build only — not launching"
  exit 0
fi
APP=$(find "$DERIVED/Build/Products" -name "*.app" -path "*iphonesimulator*" | head -1)
[ -n "$APP" ] || { echo "No .app built under $DERIVED"; exit 1; }

echo "▶ Installing $APP"
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

if [ "$GAMES" = "plunge" ]; then
  GAMES=22   # 33 powers × 2 balls = 66 plunges = 22 three-ball games per pass (for the budget below)
  ARGS=(-playlab "$TABLE" -playlab-plunge 2 -playlab-hz "$HZ" -playlab-build "$BUILD_ID")
  CAP=${CAP:-240}
else
  ARGS=(-playlab "$TABLE" -playlab-games "$GAMES" -playlab-hz "$HZ" -playlab-build "$BUILD_ID")
fi
[ -n "$SKILLS" ] && ARGS+=(-playlab-skills "$SKILLS")
echo "▶ Launching the Play Lab: ${ARGS[*]} (the app quits by itself when the report is saved)"
# Round 5: this table's reports only (other tables may be playing on other devices at the same time), and only one
# written after this launch (a marker file's mtime).
case "$TABLE" in
  lamplight)    PAT="playlab-the-lamplight-*.json";;
  greyinvasion) PAT="playlab-grey-invasion-*.json";;
  cthulhu)      PAT="playlab-cthulhu-rising-*.json";;
  *)            PAT="playlab-$TABLE-*.json";;
esac
MARKER="$DERIVED/launch-$TABLE.marker"
touch "$MARKER"
# Plan 2 round 4: the run gets a budget — the app's game cap (480 s unless CAP is set) × the games planned, plus 10 min
# for serves, saves and screenshots. A run that hasn't quit by then has stalled (a hung app, a wedged Simulator): the
# app is terminated, there is no report, and the runner exits 2 so a sweep can retry.
NSK=4; [ -n "$SKILLS" ] && NSK=$(echo "$SKILLS" | tr ',' '\n' | grep -c .)
NPASS=2; [ "$HZ" != "both" ] && NPASS=1
BUDGET=$(( 3 * (GAMES * NSK * NPASS * ${CAP:-480} + 600) ))
# 2026-10-29: slow runs are not stalls — the app saves the report after every game now, so the run is stopped only
# when nothing in ShotLab/ has been written for IDLE_MIN minutes (default 25), or at the hard cap above.
IDLE_MIN=${IDLE_MIN:-25}
echo "▶ Stops if nothing is written for $IDLE_MIN min (hard cap $(( BUDGET / 60 )) min); the report is saved after every game"
# --console attaches to the app's stdout and returns when it exits; watched from here so it can be cut short.
( xcrun simctl launch --console "$UDID" "$BUNDLE" "${ARGS[@]}" | grep -E "LAB:|PLAY LAB" || true ) &
WATCH=$!
T_LAUNCH=$(date +%s)
STALLED=
while kill -0 "$WATCH" 2>/dev/null; do
  sleep 20
  ELAPSED=$(( $(date +%s) - T_LAUNCH ))
  IDLE=
  if [ "$ELAPSED" -gt $(( IDLE_MIN * 60 )) ] && [ -z "$(find ShotLab -newer "$MARKER" -mmin -"$IDLE_MIN" 2>/dev/null | head -1)" ]; then
    IDLE=1
  fi
  if [ -n "$IDLE" ] || [ "$ELAPSED" -gt "$BUDGET" ]; then
    if [ -n "$IDLE" ]; then
      echo "▶ STALLED: nothing written to ShotLab/ for $IDLE_MIN min — terminating it"
    else
      echo "▶ STOPPED: the hard cap of $(( BUDGET / 60 )) min — terminating it (finished games are in the report)"
    fi
    STALLED=1
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    sleep 5
    kill "$WATCH" 2>/dev/null || true
    break
  fi
done
wait "$WATCH" 2>/dev/null || true

AFTER=$(find ShotLab -maxdepth 1 -name "$PAT" ! -name "*-sweep.json" -newer "$MARKER" 2>/dev/null | head -1 || true)
if [ -n "$AFTER" ]; then
  echo "▶ Report: $AFTER"
  STEM="${AFTER%.json}"
  # Shots meant to be hard on this table (an expert rate under 15% is noted, not flagged).
  case "$TABLE" in lamplight) PRECISE="mail";; *) PRECISE="";; esac
  python3 tools/playlab_report.py "$AFTER" --tracks "$STEM-tracks.svg" --html ${PRECISE:+--precise $PRECISE}
  echo "▶ Report page: $STEM.html (screenshots in $STEM/, tracks in $STEM-tracks.svg)"
  open "$STEM.html" 2>/dev/null || true
else
  echo "No new report in ShotLab/ (${STALLED:+the run stalled and was terminated}${STALLED:-did the app quit early? check the Simulator})."
  exit 2
fi
