#!/usr/bin/env bash
# queue-mark-done.sh — mark a task-registry.jsonl item as shipped
# Usage: queue-mark-done.sh <ITEM_ID> <NOTES> [IMPL_FILES]
#   IMPL_FILES (optional): comma-separated list of files changed, or "auto" to detect from git
# Appends a done entry to task-registry.jsonl with status=done + shipped_at timestamp.
# Also appends a done record to engineer-queue.md (status: done, completed_at: — no queued_at: so bot.js ignores it).
# Also updates work-items.json to status=done to prevent PM re-queuing on next sweep.
# Call this after every engineer queue item is delivered.

set -euo pipefail

REGISTRY_FILE="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
WORK_ITEMS_FILE="/Users/{{USER_HOME}}/helm-workspace/work-items.json"
ITEM_ID="${1:-}"
NOTES="${2:-}"
IMPL_FILES="${3:-auto}"

if [[ -z "$ITEM_ID" ]]; then
  echo "Usage: queue-mark-done.sh <ITEM_ID> <NOTES>" >&2
  exit 1
fi

# Reject empty notes — empty notes = B-01 violation (claiming done without proving it)
if [[ -z "$NOTES" || "$NOTES" == '""' || ${#NOTES} -lt 10 ]]; then
  echo "ERROR: NOTES is required and must be at least 10 chars. Empty notes = B-01 violation." >&2
  echo "  Usage: queue-mark-done.sh \"$ITEM_ID\" \"what was done and what file/commit proves it\"" >&2
  exit 1
fi

SHIPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Escape special chars in NOTES for JSON
NOTES_ESCAPED=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" <<< "$NOTES")

# Option B: Capture implementation files to enrich impl-check.sh search corpus.
# "auto" = detect from recent git diff; explicit list = use as-is; empty = skip.
IMPL_FILES_RESOLVED=""
if [[ "$IMPL_FILES" == "auto" ]]; then
  IMPL_FILES_RESOLVED=$(git -C "$HOME/marvin-bot" diff --name-only HEAD~1 HEAD 2>/dev/null \
    | head -10 | tr '\n' ',' | sed 's/,$//' || true)
  if [[ -z "$IMPL_FILES_RESOLVED" ]]; then
    IMPL_FILES_RESOLVED=$(git -C "$HOME/helm-config" diff --name-only HEAD~1 HEAD 2>/dev/null \
      | head -10 | tr '\n' ',' | sed 's/,$//' || true)
  fi
elif [[ -n "$IMPL_FILES" ]]; then
  IMPL_FILES_RESOLVED="$IMPL_FILES"
fi

# Append done entry to task-registry.jsonl
python3 -c "
import json, os
f = os.path.expanduser('$REGISTRY_FILE')
entry = {
    'id': '$ITEM_ID',
    'status': 'done',
    'shipped_at': '$SHIPPED_AT',
    'notes': ${NOTES_ESCAPED}
}
if '$IMPL_FILES_RESOLVED':
    entry['implementation_files'] = '$IMPL_FILES_RESOLVED'
open(f, 'a').write(json.dumps(entry) + '\n')
print('✓ Marked done in task-registry: $ITEM_ID at $SHIPPED_AT')
"

# Append done record to engineer-queue.md (no queued_at: → bot.js watcher won't trigger)
ENGINEER_QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
IMPL_LINE=""
[[ -n "$IMPL_FILES_RESOLVED" ]] && IMPL_LINE="implementation_files: $IMPL_FILES_RESOLVED"
cat >> "$ENGINEER_QUEUE_FILE" << EOF

---
completed_at: $SHIPPED_AT
id: $ITEM_ID
status: done
notes: $NOTES
${IMPL_LINE}
---
EOF
echo "✓ Done record written to engineer-queue.md: $ITEM_ID"

# Also update work-items.json status to done (prevents PM re-queuing on next sweep)
python3 -c "
import json, os, time
f = '$WORK_ITEMS_FILE'
if not os.path.exists(f):
    print('  work-items.json not found — skipping work-items update')
    exit(0)
with open(f) as fh:
    data = json.load(fh)
items = data.get('items', [])
matched = 0
for item in items:
    if item.get('id') == '$ITEM_ID' or item.get('id', '').upper() == '$ITEM_ID'.upper():
        if item.get('status') != 'done':
            item['status'] = 'done'
            item['verified_by'] = 'queue-mark-done.sh at $SHIPPED_AT — ${NOTES_ESCAPED}'
            matched += 1
if matched:
    data['last_updated'] = '$SHIPPED_AT'
    data['updated_by'] = 'queue-mark-done.sh'
    with open(f, 'w') as fh:
        json.dump(data, fh, indent=2)
    print(f'  ✓ Updated work-items.json: {matched} item(s) marked done')
else:
    print('  work-items.json: no item matched ID $ITEM_ID (may be registry-only item — ok)')
" 2>/dev/null || echo "  work-items.json update failed (non-fatal)"
