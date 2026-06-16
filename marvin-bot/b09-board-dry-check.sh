#!/usr/bin/env bash
# b09-board-dry-check.sh — ENG-B09-NEGSPACE-001 b09_board_dry detector
# Run at end of each PM sweep. Logs b09_no_advance to friction-log if:
#   - fewer than 3 non-blocked/non-done streams are active
#   - AND approved-but-unseeded work exists (BUILD-ROADMAP items not yet started)
# Usage: bash ~/marvin-bot/b09-board-dry-check.sh

set -euo pipefail

WORKSTREAMS="$HOME/helm-workspace/system/workstreams.json"
BUILD_ROADMAP="$HOME/helm-workspace/product/BUILD-ROADMAP.md"
FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
DECISIONS_LOG="$HOME/helm-workspace/system/decisions-log.md"

LOG_TAG="[b09-board-dry $(date -u +%H:%M:%SZ)]"

if [[ ! -f "$WORKSTREAMS" ]]; then
    echo "$LOG_TAG workstreams.json not found — skipping"
    exit 0
fi

# Count non-blocked, non-done streams
ACTIVE_COUNT=$(python3 - <<'PYEOF'
import json, sys
try:
    ws = json.load(open("/Users/{{USER_HOME}}/helm-workspace/system/workstreams.json"))
    streams = ws.get("streams", [])
    inactive = {"blocked", "blocked-on-jerry", "done", "archived", "cancelled"}
    active = [s for s in streams if s.get("status", "").lower() not in inactive]
    print(len(active))
except Exception as e:
    print(0)
PYEOF
)

echo "$LOG_TAG Active (non-blocked) streams: $ACTIVE_COUNT"

if [[ "$ACTIVE_COUNT" -ge 3 ]]; then
    echo "$LOG_TAG Board has $ACTIVE_COUNT active streams — no b09_board_dry violation"
    exit 0
fi

# Check for approved-but-unseeded work in BUILD-ROADMAP.md
# Look for items/phases that are listed without a "✅" done marker
HAS_UNSEEDED=false
if [[ -f "$BUILD_ROADMAP" ]]; then
    UNSEEDED_COUNT=$(grep -c "^\| *[A-Z0-9-]\+ *\|" "$BUILD_ROADMAP" | grep -v "✅" 2>/dev/null || true)
    # Simpler: count lines with table rows that don't contain ✅ Fixed or DONE
    UNSEEDED_LINES=$(grep -E "^\| [A-Z]" "$BUILD_ROADMAP" | grep -cv "✅\|DONE\|done\|**Done**\|blocked" 2>/dev/null || echo "0")
    if [[ "$UNSEEDED_LINES" -gt 0 ]]; then
        HAS_UNSEEDED=true
        echo "$LOG_TAG Found $UNSEEDED_LINES unseeded BUILD-ROADMAP items"
    fi
fi

if [[ "$HAS_UNSEEDED" == "true" ]]; then
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    B09_LINE="[$TS] B09-BOARD-DRY active_streams=$ACTIVE_COUNT unseeded_roadmap_items=$UNSEEDED_LINES — fewer than 3 active streams with approved-but-unseeded work exists\n"
    printf "%b" "$B09_LINE" >> "$FRICTION_LOG"
    echo "$LOG_TAG Logged b09_no_advance to friction-log"

    # Log to decisions-log for PM visibility
    printf "\n## [%s] B09-BOARD-DRY detected\n- Active streams: %d (threshold: 3)\n- Unseeded roadmap items: %d\n- Action: PM should seed new streams from BUILD-ROADMAP\n" \
        "$(date -u '+%Y-%m-%d %H:%M')" "$ACTIVE_COUNT" "$UNSEEDED_LINES" >> "$DECISIONS_LOG"
else
    echo "$LOG_TAG Active streams low ($ACTIVE_COUNT) but no unseeded roadmap items found — no violation"
fi
