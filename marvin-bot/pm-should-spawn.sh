#!/bin/bash
# pm-should-spawn.sh — Pre-filter for PM cron sweeps.
# Outputs "SPAWN" or "SKIP" to stdout.
# Logic: if no new user activity since last PM sweep AND engineer-queue has active work, skip.
# Saves skip reason to pm-skip-log.jsonl.

EVENT_STREAM="$HOME/helm-workspace/event-stream.jsonl"
DECISIONS_LOG="$HOME/helm-workspace/decisions-log.md"
ENGINEER_QUEUE="$HOME/helm-workspace/engineer-queue.md"
SKIP_LOG="$HOME/helm-workspace/pm-skip-log.jsonl"
WORKSTREAMS="$HOME/helm-workspace/system/workstreams.json"

# B-09 guard: ready workstreams mean PM has proactive work to advance (T1-W).
# Skipping the spawn here was the exact failure mode that made B-09 invisible —
# "no new user activity" is precisely when proactive advancement should happen.
READY_STREAMS=$(python3 -c "
import json
try:
    d = json.load(open('$WORKSTREAMS'))
    print(sum(1 for s in d.get('streams', d.get('workstreams', [])) if s.get('status') == 'ready'))
except Exception:
    print(0)
" 2>/dev/null)
if [ "${READY_STREAMS:-0}" -gt 0 ]; then
    echo "SPAWN"
    exit 0
fi

# Get last user_message timestamp from event-stream
LAST_USER_MSG_TS=$(python3 -c "
import sys
last = None
with open('$EVENT_STREAM') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            import json
            d = json.loads(line)
            if d.get('type') == 'user_message':
                last = d.get('ts','')
        except:
            pass
print(last or '')
" 2>/dev/null)

# Get last PM sweep timestamp from decisions-log
LAST_PM_SWEEP_TS=$(python3 -c "
import re, sys
last = None
# Match lines like '## 2026-05-22 16:10:00Z' or timestamps within PM entries
with open('$DECISIONS_LOG') as f:
    content = f.read()
# Find all ISO timestamps that appear in PM sweep context
# Look for entries that contain 'Trigger: schedule' or 'PM idle-sweep'
blocks = content.split('\n## ')
for block in reversed(blocks):
    if 'Trigger: schedule' in block or 'pm_idle' in block or 'pm_skip' in block:
        m = re.search(r'(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2})?Z?)', block)
        if m:
            last = m.group(1).replace(' ','T')
            if not last.endswith('Z'):
                last += 'Z'
            break
    # Also match header timestamps like '## [2026-05-22 16:07]'
    m = re.search(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]', block[:80])
    if m and ('product-manager' in block[:300] or 'PM ' in block[:300] or 'Trigger:' in block[:300]):
        last = m.group(1).replace(' ','T') + ':00Z'
        break
print(last or '')
" 2>/dev/null)

# Check if engineer-queue has active items
QUEUE_ITEMS=$(grep -c "^queued_at:" "$ENGINEER_QUEUE" 2>/dev/null || echo 0)

# Compare timestamps using Python
DECISION=$(python3 -c "
import sys
from datetime import datetime, timezone

user_ts = '$LAST_USER_MSG_TS'
sweep_ts = '$LAST_PM_SWEEP_TS'
queue_items = $QUEUE_ITEMS

def parse_ts(ts):
    if not ts:
        return None
    ts = ts.strip()
    for fmt in ['%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%dT%H:%M:%SZ']:
        try:
            return datetime.strptime(ts, fmt).replace(tzinfo=timezone.utc)
        except:
            pass
    return None

user_dt = parse_ts(user_ts)
sweep_dt = parse_ts(sweep_ts)

# If we can't parse, default to SPAWN (safe)
if not user_dt:
    print('SPAWN')
    sys.exit(0)

if not sweep_dt:
    print('SPAWN')
    sys.exit(0)

# If new user activity since last sweep → SPAWN
if user_dt >= sweep_dt:
    print('SPAWN')
    sys.exit(0)

# No new user activity + queue has active work → SKIP
if queue_items > 0:
    print('SKIP')
    sys.exit(0)

# No new activity + empty queue → SPAWN (PM should check backlog)
print('SPAWN')
" 2>/dev/null)

DECISION="${DECISION:-SPAWN}"

# Log skips
if [ "$DECISION" = "SKIP" ]; then
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"ts\":\"$TS\",\"reason\":\"no_new_user_activity_queue_active\",\"last_user_msg_ts\":\"$LAST_USER_MSG_TS\",\"last_sweep_ts\":\"$LAST_PM_SWEEP_TS\",\"queue_items\":$QUEUE_ITEMS}" >> "$SKIP_LOG"
fi

echo "$DECISION"
