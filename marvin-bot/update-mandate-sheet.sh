#!/usr/bin/env bash
# update-mandate-sheet.sh — Push behavior-metrics.json to Mandates tab in Google Sheets
# Usage: bash ~/marvin-bot/update-mandate-sheet.sh
# Reads:  ~/helm-workspace/behavior-metrics.json
# Writes: Google Sheets ID 1zIV0uyCL-4nr1v6IUElJKBNXj6y8oU-Tmp-cR5ruU5Y, tab "Mandates"
# Called by: PM T2-L after each daily sweep
#
# Requires pap-sheets.sh to be functional (Apps Script deployment live).
# On failure (HTML response / network error), exits 1 with clear message — no data loss.

set -euo pipefail

METRICS_FILE="$HOME/helm-workspace/behavior-metrics.json"
PAP_SHEETS="$HOME/helm-workspace/scripts/pap-sheets.sh"
SHEET_ID="1zIV0uyCL-4nr1v6IUElJKBNXj6y8oU-Tmp-cR5ruU5Y"
TAB_NAME="Mandates"

LOG_TAG="[update-mandate-sheet $(date -u +%H:%M:%SZ)]"

if [[ ! -f "$METRICS_FILE" ]]; then
    echo "$LOG_TAG behavior-metrics.json not found — skipping"
    exit 0
fi

if [[ ! -f "$PAP_SHEETS" ]]; then
    echo "$LOG_TAG pap-sheets.sh not found at $PAP_SHEETS — skipping"
    exit 1
fi

# ── 1. Build rows from behavior-metrics.json ─────────────────────────────────

ROWS_JSON=$(python3 - <<'PYEOF'
import json, sys
from datetime import datetime

METRICS_FILE = "/Users/{{USER_HOME}}/helm-workspace/behavior-metrics.json"

with open(METRICS_FILE) as f:
    m = json.load(f)

generated_at = m.get("generated_at", "")
days = m.get("days", 30)
total = m.get("total_violations", 0)
target_info = m.get("improvement_target", {})
target = target_info.get("target", "")
target_date = target_info.get("target_date", "")
baseline = target_info.get("baseline", "")
per_targets = m.get("per_behavior_targets", {})
by_behavior = m.get("by_behavior", {})
top_3 = m.get("top_3", [])

# Last semantic review summary (if present)
semantic = m.get("last_semantic_review", {})
semantic_failure = semantic.get("top_semantic_failure", "")
semantic_type = semantic.get("failure_type", "")
semantic_fix = semantic.get("recommended_fix", "")
semantic_reviewed_at = semantic.get("reviewed_at", "")

rows = []

# Header
rows.append(["Behavior", f"{days}d Violations", "Last Seen", "Monthly Cap", "Status", "Notes"])

# Sort by count descending
sorted_behaviors = sorted(by_behavior.items(), key=lambda x: x[1].get("count", 0), reverse=True)

for bname, bdata in sorted_behaviors:
    count = bdata.get("count", 0)
    last_seen = bdata.get("last_seen", "")
    cap = per_targets.get(bname, {}).get("monthly_cap", None)
    cap_str = str(cap) if cap is not None else "—"
    # Only compare numerically if cap is a number
    if isinstance(cap, (int, float)) and cap > 0:
        status = "🔴 OVER CAP" if count > cap else ("⚠️ AT RISK" if count > (cap * 0.7) else "✅ OK")
    else:
        status = "—"
    notes = "TOP 3" if bname in top_3 else ""
    rows.append([bname, count, last_seen, cap_str, status, notes])

# Summary section
rows.append(["", "", "", "", "", ""])
rows.append(["TOTAL", total, "", "", "", f"Baseline: {baseline} | Target: {target} by {target_date}"])

# Semantic review row if present
if semantic_failure:
    rows.append(["", "", "", "", "", ""])
    rows.append(["SEMANTIC REVIEW", semantic_reviewed_at, semantic_type, "", semantic_failure, semantic_fix])

rows.append(["", "", "", "", "", ""])
rows.append(["Updated", generated_at, "", "", "", ""])

print(json.dumps(rows))
PYEOF
)

ROW_COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" <<< "$ROWS_JSON")
echo "$LOG_TAG Built $ROW_COUNT rows from behavior-metrics.json"

# ── 2. Call pap-sheets.sh ────────────────────────────────────────────────────

PAYLOAD=$(python3 -c "
import json, sys
rows = json.loads(sys.argv[1])
payload = {
    'action': 'add_tab_and_write',
    'sheet_id': sys.argv[2],
    'tab_name': sys.argv[3],
    'rows': rows
}
print(json.dumps(payload))
" "$ROWS_JSON" "$SHEET_ID" "$TAB_NAME")

echo "$LOG_TAG Calling pap-sheets.sh → sheet $SHEET_ID tab '$TAB_NAME'"

RESPONSE=$(bash "$PAP_SHEETS" "$PAYLOAD" 2>/dev/null || echo "CURL_FAILED")

# ── 3. Check response ────────────────────────────────────────────────────────

if [[ "$RESPONSE" == "CURL_FAILED" ]]; then
    echo "$LOG_TAG ERROR: pap-sheets.sh curl call failed"
    exit 1
fi

# Detect HTML response (Apps Script URL dead or revoked)
FIRST_CHAR="${RESPONSE:0:1}"
if [[ "$FIRST_CHAR" != "{" && "$FIRST_CHAR" != "[" ]]; then
    echo "$LOG_TAG ERROR: pap-sheets.sh returned non-JSON response (Apps Script URL may need re-deployment)"
    echo "$LOG_TAG First 200 chars: ${RESPONSE:0:200}"
    exit 1
fi

# Parse success/error from JSON
SUCCESS=$(python3 -c "
import json, sys
try:
    r = json.loads(sys.argv[1])
    print('true' if r.get('ok') or r.get('result') else 'false')
    if not (r.get('ok') or r.get('result')):
        print(r.get('error', 'unknown error'), file=sys.stderr)
except Exception as e:
    print('false')
    print(str(e), file=sys.stderr)
" "$RESPONSE" 2>/tmp/sheets-err.txt || echo "false")

if [[ "$SUCCESS" == "true" ]]; then
    echo "$LOG_TAG OK — Mandates tab updated ($ROW_COUNT rows written)"
else
    ERR=$(cat /tmp/sheets-err.txt 2>/dev/null || echo "unknown")
    echo "$LOG_TAG ERROR: Sheets write failed — $ERR"
    echo "$LOG_TAG Raw response: ${RESPONSE:0:300}"
    exit 1
fi
