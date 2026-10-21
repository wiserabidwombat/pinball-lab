#!/bin/bash
# Pinball Lab · Play Lab sweep (macOS). Plays every table that hosts the Play Lab, one after another, in the iOS
# Simulator — the overnight run. Builds once, runs tools/playlab_run.sh per table (each writes its own JSON + page in
# ShotLab/), then writes one index page that compares the tables: ShotLab/sweep-<stamp>.html. Run from the project
# root in Terminal; the Mac is kept awake with caffeinate while it runs.
#
#   tools/playlab_sweep.sh                       # all tables, 2 games per skill, both passes (~4–5 h)
#   tools/playlab_sweep.sh 1 120                 # 1 game per skill, 120 Hz only (~1.5 h)
#   tools/playlab_sweep.sh 2 both lamplight monsoon   # just these tables
#   SKIP_BUILD=1 tools/playlab_sweep.sh          # reuse the last build
#
# A table that fails (no report) is noted and the sweep carries on. Ctrl-C stops the sweep; the index is still written
# for the tables that finished.
set -uo pipefail
GAMES=${1:-2}
HZ=${2:-both}
shift 2 2>/dev/null || shift $# 2>/dev/null
TABLES=("$@")
[ ${#TABLES[@]} -gt 0 ] || TABLES=(lamplight greyinvasion cthulhu monsoon)
cd "$(dirname "$0")/.."
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
LOG=ShotLab/sweep-$STAMP.log
mkdir -p ShotLab
REPORTS=()
FAILED=()

finish() {
  echo "▶ Sweep index…" | tee -a "$LOG"
  if [ ${#REPORTS[@]} -gt 0 ]; then
    FAILED_CSV=$(IFS=,; echo "${FAILED[*]-}")
    python3 tools/playlab_index.py --out "ShotLab/sweep-$STAMP.html" --games "$GAMES" --hz "$HZ" \
      --failed "$FAILED_CSV" "${REPORTS[@]}" | tee -a "$LOG"
    echo "▶ Index: ShotLab/sweep-$STAMP.html (log: $LOG)" | tee -a "$LOG"
    open "ShotLab/sweep-$STAMP.html" 2>/dev/null || true
  else
    echo "No reports — nothing to index (log: $LOG)" | tee -a "$LOG"
  fi
}
trap 'echo "▶ Sweep interrupted" | tee -a "$LOG"; finish; exit 130' INT TERM

echo "▶ Play Lab sweep $STAMP: tables ${TABLES[*]} · $GAMES game(s) per skill · $HZ" | tee "$LOG"
START=$(date +%s)
first=1
for t in "${TABLES[@]}"; do
  echo "▶ $(date '+%H:%M') · $t" | tee -a "$LOG"
  T0=$(date +%s)
  # Build on the first table only (unless SKIP_BUILD was set for the whole sweep); the later ones reuse it.
  last=$(sed -n 's/^▶ Report: //p' "$LOG" | tail -1)
  if [ "$first" = 1 ] && [ -z "${SKIP_BUILD:-}" ]; then
    caffeinate -dims tools/playlab_run.sh "$t" "$GAMES" "$HZ" 2>&1 | tee -a "$LOG"
  else
    SKIP_BUILD=1 caffeinate -dims tools/playlab_run.sh "$t" "$GAMES" "$HZ" 2>&1 | tee -a "$LOG"
  fi
  first=0
  report=$(sed -n 's/^▶ Report: //p' "$LOG" | tail -1)
  if [ -n "$report" ] && [ "$report" != "$last" ] && [ -f "$report" ]; then
    REPORTS+=("$report")
    echo "▶ $t done in $(( ($(date +%s) - T0) / 60 )) min → $report" | tee -a "$LOG"
  else
    FAILED+=("$t")
    echo "▶ $t: NO REPORT (see $LOG)" | tee -a "$LOG"
  fi
done
echo "▶ Sweep played in $(( ($(date +%s) - START) / 60 )) min" | tee -a "$LOG"
finish
