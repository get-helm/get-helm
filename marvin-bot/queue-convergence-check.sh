#!/usr/bin/env bash
# queue-convergence-check.sh — detect divergence between queue-audit.log and engineer-queue.md
# Usage: bash queue-convergence-check.sh [--alert-only]
# Exit 0 = no divergence (or divergence too recent to alert)
# Exit 1 = divergence detected and alert threshold crossed
#
# Divergence = item appears as QUEUED in queue-audit.log (last 2h)
#              but NOT in task-registry.jsonl as done
#              AND NOT findable in engineer-queue.md
#
# Runs on every engineer spawn (via engineer.md step 1a).
# Also runs via launchd watchdog every 5 min (com.pap.queue-convergence.plist).

set -euo pipefail

AUDIT_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
REGISTRY_FILE="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
STATE_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-convergence-state.json"
LOG_FILE="/Users/{{USER_HOME}}/helm-workspace/logs/queue-convergence.log"
ALERT_THRESHOLD_SEC=900  # 15 minutes

mkdir -p "$(dirname "$LOG_FILE")"

NOW=$(date -u +%s)
CUTOFF=$((NOW - 7200))  # look back 2 hours

# Load Discord token
DISCORD_BOT_TOKEN=""
[ -f ~/marvin-bot/.env ] && DISCORD_BOT_TOKEN=$(grep -o 'DISCORD_BOT_TOKEN=[^ ]*' ~/marvin-bot/.env | cut -d= -f2 | tr -d '"' | tr -d "'")
PAP_AUDIT_CHANNEL="{{USER_CHANNEL_HELM_AUDIT}}"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"
}

# --- Step 1: Get done + in-progress item IDs from task-registry.jsonl ---
TERMINAL_IDS=$(python3 -c "
import json, sys
terminal = set()
try:
    with open('$REGISTRY_FILE') as f:
        for line in f:
            try:
                d = json.loads(line.strip())
                # done or in-progress (claimed) are not divergent
                if d.get('status') in ('done', 'in_progress', 'cancelled'):
                    terminal.add(d['id'])
            except: pass
except: pass
print('\n'.join(terminal))
" 2>/dev/null)

# --- Step 2: Get engineer-queue.md content for substring matching ---
QUEUE_CONTENT=$(cat "$QUEUE_FILE" 2>/dev/null || echo "")

# --- Step 3: Parse queue-audit.log for recent QUEUED entries ---
# Format 1: "2026-06-05T23:43:02Z | QUEUED | ITEM_ID: description..."
# Format 2: "[2026-06-06T00:15:00Z] | QUEUED | ITEM_ID description..."
DIVERGENT_JSON=$(python3 << 'PYEOF'
import re, sys, json, os
from datetime import datetime, timezone

audit_file = "/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
queue_content = open("/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md").read() if os.path.exists("/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md") else ""
registry_file = "/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
cutoff = int(os.environ.get("NOW", "0")) - 7200
now = int(os.environ.get("NOW", "0"))

# Load terminal IDs
terminal_ids = set()
try:
    with open(registry_file) as f:
        for line in f:
            try:
                d = json.loads(line.strip())
                if d.get("status") in ("done", "in_progress", "cancelled"):
                    terminal_ids.add(d["id"])
            except: pass
except: pass

# Parse patterns
pat1 = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\s*\|\s*QUEUED\s*\|\s*([A-Z0-9][A-Z0-9_-]*)[:\s]")
pat2 = re.compile(r"^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\]\s*\|\s*QUEUED\s*\|\s*([A-Z0-9][A-Z0-9_-]*)")

divergent = {}
try:
    with open(audit_file) as f:
        for line in f:
            line = line.strip()
            m = pat1.match(line) or pat2.match(line)
            if not m:
                continue
            ts_str, item_id = m.group(1), m.group(2)
            try:
                dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                ts_epoch = int(dt.timestamp())
            except:
                continue
            # Skip if outside 2h window or within 60s (might still be processing)
            if ts_epoch < cutoff or (now - ts_epoch) < 60:
                continue
            # Skip if already terminal (done, in-progress, cancelled)
            if item_id in terminal_ids:
                continue
            # Skip if item_id found in engineer-queue.md
            if item_id in queue_content:
                continue
            # It's divergent
            if item_id not in divergent:
                divergent[item_id] = ts_str
except Exception as e:
    print(f"[]", file=sys.stderr)

print(json.dumps(divergent))
PYEOF
)

# Set NOW for Python subshell
export NOW

DIVERGENT_IDS=$(python3 -c "import json; d=json.loads('$DIVERGENT_JSON'); print('\n'.join(d.keys()))" 2>/dev/null || echo "")

if [ -z "$DIVERGENT_IDS" ]; then
    log "OK: no divergence detected"
    # Clear state file
    echo '{"divergent":{}}' > "$STATE_FILE"
    exit 0
fi

COUNT=$(echo "$DIVERGENT_IDS" | grep -c . || echo 0)
log "DIVERGENT: $COUNT item(s): $(echo "$DIVERGENT_IDS" | tr '\n' ' ')"

# --- Step 4: Load state file, check age of divergence ---
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo '{"divergent":{}}')

ALERT_ITEMS=()
NEW_STATE=$(python3 << PYEOF2
import json, os, sys

divergent_json = $DIVERGENT_JSON
current_state = json.loads('''$CURRENT_STATE''')
now = $NOW
alert_threshold = $ALERT_THRESHOLD_SEC

state_divergent = current_state.get("divergent", {})
new_divergent = {}
alert_items = []

for item_id, queued_at in divergent_json.items():
    # When was this first seen as divergent?
    first_seen = state_divergent.get(item_id, {}).get("first_seen", now)
    age = now - first_seen
    new_divergent[item_id] = {"first_seen": first_seen, "queued_at": queued_at, "age_sec": age}
    if age >= alert_threshold:
        alert_items.append(f"{item_id} (queued {queued_at}, divergent {age//60}min)")

print(json.dumps({"divergent": new_divergent, "alert_items": alert_items}))
PYEOF2
)

# Save updated state
python3 -c "import json; d=json.loads('$NEW_STATE'); open('$STATE_FILE','w').write(json.dumps({'divergent': d['divergent']}, indent=2))" 2>/dev/null || true

ALERT_ITEMS_JSON=$(python3 -c "import json; d=json.loads('$NEW_STATE'); print(json.dumps(d.get('alert_items',[])))" 2>/dev/null || echo "[]")
ALERT_COUNT=$(python3 -c "import json; print(len(json.loads('$ALERT_ITEMS_JSON')))" 2>/dev/null || echo "0")

if [ "$ALERT_COUNT" -gt 0 ] && [ -n "$DISCORD_BOT_TOKEN" ]; then
    ALERT_MSG=$(python3 -c "
import json
items = json.loads('$ALERT_ITEMS_JSON')
count = len(items)
names = ', '.join(items[:5])
print(f'⚠️ Queue divergence: {count} item(s) in queue-audit.log as QUEUED for >15min but NOT in engineer-queue.md or task-registry: {names}. PM may have bypassed queue-write.sh. Check queue-audit.log and engineer-queue.md for manual reconciliation.')
" 2>/dev/null || echo "⚠️ Queue divergence detected — check queue-audit.log vs engineer-queue.md")

    ~/marvin-bot/discord-post.sh {{USER_CHANNEL_HELM_IMPROVEMENTS}} "$ALERT_MSG" 2>/dev/null || true
    log "ALERT sent to helm-improvements: $ALERT_COUNT items"
    exit 1
fi

# Divergent but not yet old enough to alert
log "PENDING: $COUNT divergent item(s), none yet >15min old"
exit 0
