#!/bin/bash
# Pinball Lab · Play Lab sweep (macOS). Plays every table that hosts the Play Lab in the iOS Simulator — the overnight
# run. Builds once, runs tools/playlab_run.sh per table (each writes its own JSON + page in ShotLab/), then writes one
# index page that compares the tables: ShotLab/sweep-<stamp>.html (+ a .json manifest naming its reports). Run from
# the project root in Terminal; the Mac is kept awake with caffeinate while it runs.
#
#   tools/playlab_sweep.sh                       # all tables, 2 games per skill, both passes (~4–5 h)
#   tools/playlab_sweep.sh 1 120                 # 1 game per skill, 120 Hz only (~1.5 h)
#   tools/playlab_sweep.sh 2 both lamplight monsoon   # just these tables
#   SKIP_BUILD=1 tools/playlab_sweep.sh          # reuse the last build
#   BASELINE=latest tools/playlab_sweep.sh       # plan 2 round 3: the index shows deltas vs the newest earlier sweep
#   BASELINE=2026-10-23T12-14-26Z tools/playlab_sweep.sh   # … or vs that sweep (its sweep-<stamp>.json or .log)
#   UNTIL_TIGHT=0.5 tools/playlab_sweep.sh       # plan 2 round 2: after each table's planned games, keep adding 1 game
#                                                # per skill (both passes) until the advanced/expert drains/min bands are
#                                                # within ±0.5, or BUDGET_MIN (default 60) extra minutes per table are
#                                                # spent; the games are merged into playlab-<table>-<stamp>-sweep.json
#                                                # (tools/playlab_merge.py) and the index reads the merged report.
#   PARALLEL=2 tools/playlab_sweep.sh            # plan 2 round 5: two tables at once on two Simulator devices (the
#                                                # device DEVICE plus clones "<DEVICE> · lab 2", "· lab 3", … made with
#                                                # `simctl clone` the first time). 4 tables at PARALLEL=4 take ~1.5 h
#                                                # instead of ~4.5 h if the Mac has the memory (each device ~2 GB).
#
# A table that fails (no report — a stalled run is terminated by playlab_run.sh after its budget) is retried ONCE after
# its Simulator device is shut down and rebooted (plan 2 round 4); if it fails again it is noted and the sweep carries
# on. The index names the tables that needed a retry. Ctrl-C stops the sweep; the index is still written for what
# finished. Each table's own output goes to ShotLab/sweep-<stamp>-<table>.log; the terminal shows it prefixed "[table]".
set -uo pipefail
GAMES=${1:-2}
HZ=${2:-both}
shift 2 2>/dev/null || shift $# 2>/dev/null
TABLES=("$@")
[ ${#TABLES[@]} -gt 0 ] || TABLES=(lamplight greyinvasion cthulhu monsoon)
cd "$(dirname "$0")/.."
DEVICE=${DEVICE:-iPhone 17 Pro Max}
PARALLEL=${PARALLEL:-1}
[ "$PARALLEL" -ge 1 ] 2>/dev/null || PARALLEL=1
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
LOG=ShotLab/sweep-$STAMP.log
mkdir -p ShotLab build/playlab
REPORTS=()
FAILED=()
RETRIED=()
caffeinate -dims -w $$ &

say() { echo "$*" | tee -a "$LOG"; }

finish() {
  say "▶ Sweep index…"
  if [ ${#REPORTS[@]} -gt 0 ]; then
    FAILED_CSV=$(IFS=,; echo "${FAILED[*]-}")
    RETRIED_CSV=$(IFS=,; echo "${RETRIED[*]-}")
    python3 tools/playlab_index.py --out "ShotLab/sweep-$STAMP.html" --games "$GAMES" --hz "$HZ" \
      --failed "$FAILED_CSV" --retried "$RETRIED_CSV" ${BASELINE:+--baseline "$BASELINE"} "${REPORTS[@]}" | tee -a "$LOG"
    say "▶ Index: ShotLab/sweep-$STAMP.html (log: $LOG)"
    open "ShotLab/sweep-$STAMP.html" 2>/dev/null || true
  else
    say "No reports — nothing to index (log: $LOG)"
  fi
}
STOP=ShotLab/sweep-$STAMP.stop
interrupted() {
  say "▶ Sweep interrupted — stopping the runners"
  touch "$STOP"   # the table jobs check this before a retry or a top-up
  local s dev p
  for s in $(seq 1 "$PARALLEL"); do
    dev=$(device_for_slot "$s")
    xcrun simctl terminate "$(udid_of "$dev")" com.aarontilley.pinballlab 2>/dev/null || true
  done
  for p in $(pgrep -P $$); do pkill -P "$p" 2>/dev/null || true; done
  pkill -P $$ 2>/dev/null || true
  sleep 2
  collect_all
  finish
  exit 130
}
trap interrupted INT TERM

# ---------------------------------------------------------------- devices (round 5)
udid_of() {   # the UDID of an available device by name, or nothing
  xcrun simctl list devices available -j | python3 -c "
import json,sys; d=json.load(sys.stdin)
for devs in d['devices'].values():
    for x in devs:
        if x['name']==sys.argv[1]: print(x['udid']); sys.exit()
print('')" "$1"
}
device_for_slot() { if [ "$1" -eq 1 ]; then echo "$DEVICE"; else echo "$DEVICE · lab $1"; fi; }
ensure_devices() {
  local base; base=$(udid_of "$DEVICE")
  [ -n "$base" ] || { say "No simulator named '$DEVICE' (set DEVICE=...)"; exit 1; }
  local k name
  for k in $(seq 2 "$PARALLEL"); do
    name=$(device_for_slot "$k")
    if [ -z "$(udid_of "$name")" ]; then
      say "▶ Cloning '$DEVICE' → '$name' (once; the clone stays for later sweeps)"
      xcrun simctl shutdown "$base" 2>/dev/null || true
      xcrun simctl clone "$base" "$name" > /dev/null || { say "clone failed; falling back to PARALLEL=$((k - 1))"; PARALLEL=$((k - 1)); break; }
    fi
  done
}

# ---------------------------------------------------------------- one table, start to finish (run → retry → top-ups)
report_from() { sed -n 's/^▶ Report: //p' "$1" | tail -1; }
run_table() {   # $1 table, $2 slot; writes its outcome to ShotLab/sweep-$STAMP-$1.final
  local t=$1 slot=$2 dev tlog final report retried=0 T0
  dev=$(device_for_slot "$slot")
  tlog=ShotLab/sweep-$STAMP-$t.log
  final=ShotLab/sweep-$STAMP-$t.final
  T0=$(date +%s)
  say "▶ $(date '+%H:%M') · $t on '$dev'"
  DEVICE="$dev" SKIP_BUILD=1 tools/playlab_run.sh "$t" "$GAMES" "$HZ" 2>&1 | tee -a "$tlog" | while IFS= read -r l; do echo "[$t] $l"; done
  report=$(report_from "$tlog")
  # Round 4: no report → reboot this device and try the table once more (the build is reused) — unless the sweep was
  # interrupted (then the missing report is the interruption, not a failure).
  if [ ! -f "$STOP" ] && { [ -z "$report" ] || [ ! -f "$report" ]; }; then
    say "▶ $t: no report — shutting '$dev' down and retrying once"
    xcrun simctl shutdown "$(udid_of "$dev")" 2>/dev/null || true
    sleep 10
    retried=1
    DEVICE="$dev" SKIP_BUILD=1 tools/playlab_run.sh "$t" "$GAMES" "$HZ" 2>&1 | tee -a "$tlog" | while IFS= read -r l; do echo "[$t] $l"; done
    report=$(report_from "$tlog")
  fi
  if [ -n "$report" ] && [ -f "$report" ]; then
    # Round 2: UNTIL_TIGHT — top the table up one game per skill at a time until its bands are tight or the budget is spent.
    if [ -n "${UNTIL_TIGHT:-}" ] && [ ! -f "$STOP" ]; then
      local PARTS=("$report") merged="$report" tight extra_start prev more slug
      tight=$(python3 tools/playlab_report.py "$report" --tightness)
      extra_start=$(date +%s)
      say "▶ $t: drains/min half-width ±$tight (want ≤ $UNTIL_TIGHT)"
      while python3 -c "import sys; sys.exit(0 if float('$tight') > float('$UNTIL_TIGHT') else 1)" \
            && [ $(( ($(date +%s) - extra_start) / 60 )) -lt "${BUDGET_MIN:-60}" ]; do
        prev=$(report_from "$tlog")
        DEVICE="$dev" SKIP_BUILD=1 tools/playlab_run.sh "$t" 1 "$HZ" 2>&1 | tee -a "$tlog" | while IFS= read -r l; do echo "[$t] $l"; done
        more=$(report_from "$tlog")
        if [ -z "$more" ] || [ "$more" = "$prev" ] || [ ! -f "$more" ]; then
          say "▶ $t: the top-up produced no report; stopping the top-ups"; break
        fi
        PARTS+=("$more")
        slug=$(basename "$report" | sed -E 's/^playlab-(.*)-[0-9]{4}-[0-9]{2}-[0-9]{2}T.*/\1/')
        merged="ShotLab/playlab-$slug-$STAMP-sweep.json"
        python3 tools/playlab_merge.py --out "$merged" "${PARTS[@]}" | tee -a "$tlog"
        python3 tools/playlab_report.py "$merged" --tracks "${merged%.json}-tracks.svg" --html > /dev/null
        tight=$(python3 tools/playlab_report.py "$merged" --tightness)
        say "▶ $t: ${#PARTS[@]} runs merged → $merged · half-width ±$tight"
        report=$merged
      done
    fi
    say "▶ $t done in $(( ($(date +%s) - T0) / 60 )) min → $report"
    echo "OK $retried $report" > "$final"   # status · retried 0/1 · report
  else
    say "▶ $t: NO REPORT (see $tlog)"
    echo "FAIL $retried -" > "$final"
  fi
}
collect() {   # read a finished table's outcome
  local t=$1 final=ShotLab/sweep-$STAMP-$1.final status retried report
  [ -f "$final" ] || { FAILED+=("$t"); return; }
  read -r status retried report < "$final"
  [ "$retried" = "1" ] && RETRIED+=("$t")
  if [ "$status" = "OK" ]; then REPORTS+=("$report"); else FAILED+=("$t"); fi
  rm -f "$final"
}
collect_all() { local t; for t in "${STARTED[@]-}"; do [ -n "$t" ] && [ -f "ShotLab/sweep-$STAMP-$t.final" ] && collect "$t"; done; }

# ---------------------------------------------------------------- the sweep
say "▶ Play Lab sweep $STAMP: tables ${TABLES[*]} · $GAMES game(s) per skill · $HZ · parallel $PARALLEL"
START=$(date +%s)
ensure_devices
if [ -z "${SKIP_BUILD:-}" ]; then
  BUILD_ONLY=1 tools/playlab_run.sh "${TABLES[0]}" "$GAMES" "$HZ" 2>&1 | tee -a "$LOG" || { say "Build failed"; exit 1; }
fi
# A small job pool (bash 3.2: no `wait -n`): one slot per device, polled every 15 s. Finished tables are collected in
# order so REPORTS keeps the tables' order.
STARTED=()
SLOT_PID=(); SLOT_TABLE=()
next=0
for s in $(seq 1 "$PARALLEL"); do SLOT_PID[$s]=""; SLOT_TABLE[$s]=""; done
while :; do
  running=0
  for s in $(seq 1 "$PARALLEL"); do
    if [ -n "${SLOT_PID[$s]}" ] && ! kill -0 "${SLOT_PID[$s]}" 2>/dev/null; then
      SLOT_PID[$s]=""; SLOT_TABLE[$s]=""
    fi
    if [ -z "${SLOT_PID[$s]}" ] && [ "$next" -lt "${#TABLES[@]}" ]; then
      t=${TABLES[$next]}; next=$((next + 1))
      run_table "$t" "$s" &
      SLOT_PID[$s]=$!; SLOT_TABLE[$s]=$t; STARTED+=("$t")
      sleep 5
    fi
    [ -n "${SLOT_PID[$s]}" ] && running=$((running + 1))
  done
  [ "$running" -eq 0 ] && [ "$next" -ge "${#TABLES[@]}" ] && break
  sleep 15
done
for t in "${STARTED[@]-}"; do [ -n "$t" ] && collect "$t"; done
say "▶ Sweep played in $(( ($(date +%s) - START) / 60 )) min"
rm -f "$STOP"
finish
