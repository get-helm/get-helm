#!/usr/bin/env bash
# queue-start.sh — mark a task-registry.jsonl item as in-progress (AGENT-LEDGER-001)
# Usage: queue-start.sh <ITEM_ID> <CHANNEL_ID>
# Call this immediately after claiming an item from engineer-queue.md (CLAIM-FIRST step).
# Closes the INF-23 timing gap: pm-can-deliver.sh checks for in_progress status,
# so this prevents false FAIL between claim and completion.

set -euo pipefail

REGISTRY_FILE="$HOME/helm-workspace/task-registry.jsonl"
ITEM_ID="${1:-}"
CHANNEL_ID="${2:-unknown}"

if [[ -z "$ITEM_ID" ]]; then
  echo "Usage: queue-start.sh <ITEM_ID> <CHANNEL_ID>" >&2
  exit 1
fi

STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 -c "
import json, os
f = os.path.expanduser('$REGISTRY_FILE')
entry = {
    'id': '$ITEM_ID',
    'status': 'in_progress',
    'started_at': '$STARTED_AT',
    'channel_id': '$CHANNEL_ID'
}
open(f, 'a').write(json.dumps(entry) + '\n')
print('✓ Marked in_progress in task-registry: $ITEM_ID at $STARTED_AT')
"
