#!/usr/bin/env bash
# registry-cleanup.sh — mark phantom queued/in_progress registry entries as done
# Phantom = status:queued in registry but no live queued_at block in engineer-queue.md
# Per REGISTRY-FIX-B-ONLY-001 design ({{USER_JERRY}}-approved Option B)

set -euo pipefail
REGISTRY="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
QUEUE="/Users/{{USER_HOME}}/helm-workspace/system/engineer-queue.md"
LOG="/Users/{{USER_HOME}}/helm-workspace/system/decisions-log.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get live queue IDs (queued_at blocks in queue file)
live_ids=$(python3 -c "
import re
content = open('$QUEUE').read()
ids = set()
for b in content.split('---'):
    if 'queued_at:' in b and 'status: pending' in b:
        m = re.search(r'id:\s*(\S+)', b)
        if m: ids.add(m.group(1))
print(' '.join(ids))
")

# Count current phantoms
phantom_count=$(python3 -c "
import json
live = set('$live_ids'.split())
count = 0
with open('$REGISTRY') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            r = json.loads(line)
            if r.get('status') in ('queued','in_progress') and r.get('id') not in live:
                count += 1
        except: pass
print(count)
")

echo "Found $phantom_count phantom entries (queued/in_progress with no live queue block)"

# Auto-reconcile: append done records for all phantoms
python3 << PYEOF
import json, time, sys

REGISTRY = "$REGISTRY"
live_str = "$live_ids"
live = set(live_str.split()) if live_str.strip() else set()
now = "$NOW"

# Read all records, find phantom IDs (keep most recent status per ID)
records = []
with open(REGISTRY) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                records.append(json.loads(line))
            except:
                pass

# For each ID, find if it has a 'done' record already
done_ids = set(r['id'] for r in records if r.get('status') == 'done' and r.get('id'))

# Find phantom queued/in_progress (not in live queue, not already done)
phantom_ids_seen = set()
phantom_records = []
for r in records:
    iid = r.get('id')
    if not iid: continue
    if r.get('status') in ('queued', 'in_progress') and iid not in live and iid not in done_ids:
        if iid not in phantom_ids_seen:
            phantom_ids_seen.add(iid)
            phantom_records.append(r)

print(f'Unique phantom IDs to reconcile: {len(phantom_records)}')

# Append done records for all phantoms
reconciled = 0
with open(REGISTRY, 'a') as f:
    for r in phantom_records:
        done_entry = {
            'id': r['id'],
            'status': 'done',
            'shipped_at': now,
            'notes': 'auto-reconciled by registry-cleanup.sh — was phantom queued/in_progress with no live queue block',
            'reconciled': True
        }
        f.write(json.dumps(done_entry) + '\n')
        reconciled += 1

print(f'Wrote {reconciled} done records to registry')
sys.stdout.flush()
PYEOF

# Log to decisions-log
echo "## [$NOW] — registry-cleanup.sh: $phantom_count phantoms auto-reconciled (Option B cleanup)" >> "$LOG"
echo "✓ Registry cleanup complete"
