#!/bin/bash
# Captures every key screen with demo data on one simulator.
# Usage: tools/screenshots.sh <simulator-udid> <path/to/MARQUEE.app> <output-dir> <size-label> [full|ax]
set -uo pipefail
UDID="$1"; APP="$2"; OUT="$3"; SIZE="$4"; MODE="${5:-full}"
BUNDLE=com.savonstudios.marquee
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1" wait="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$SIZE-$name.png" >/dev/null 2>&1 && echo "captured $SIZE-$name"
}

screens() {
  local look="$1" prefix="$2"
  shot "$prefix-01-home" 4 -demoData -screen home -look "$look"
  shot "$prefix-02-library" 4 -demoData -screen library -look "$look"
  shot "$prefix-03-search" 4 -demoData -screen search -look "$look"
  shot "$prefix-04-search-results" 5 -demoData -screen search-results -look "$look"
  shot "$prefix-05-detail" 4 -demoData -screen detail -look "$look"
  shot "$prefix-06-detail-book" 4 -demoData -screen detail-book -look "$look"
  shot "$prefix-07-settings" 4 -demoData -screen settings -look "$look"
  if [ "$MODE" = "full" ]; then
    shot "$prefix-08-about" 3 -demoData -screen about -look "$look"
    shot "$prefix-09-diagnostics" 4 -demoData -screen diagnostics -look "$look"
    shot "$prefix-10-search-offline" 4 -demoData -offline -screen search -look "$look"
    shot "$prefix-11-search-nokey" 5 -demoData -noKey -screen search-results -look "$look"
    shot "$prefix-12-home-empty" 4 -freshStore -stubNetwork -screen home -look "$look"
    shot "$prefix-13-recently-deleted" 3 -freshStore -stubNetwork -screen deleted -look "$look"
  fi
}

if [ "$MODE" = "ax" ]; then
  xcrun simctl ui "$UDID" content_size accessibility-extra-large
  screens cinema ax3
  xcrun simctl ui "$UDID" content_size large
else
  # The opening animation, caught mid-draw and just after the shine.
  shot cinema-00-launch-a 0.6 -demoData -screen launch
  shot cinema-00-launch-b 1.0 -demoData -screen launch
  screens cinema cinema
  screens paper paper
  for look in noir bookshop neon; do
    shot "$look-01-home" 4 -demoData -screen home -look "$look"
    shot "$look-02-library" 4 -demoData -screen library -look "$look"
  done
fi

find ~/Library/Logs/DiagnosticReports -name "MARQUEE*" -newer "$APP" -exec cp {} "$OUT/" \; 2>/dev/null || true
ls -1 "$OUT" | wc -l
