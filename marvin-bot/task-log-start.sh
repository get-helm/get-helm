#!/usr/bin/env bash
# task-log-start.sh — log task start to task-registry.jsonl
# Usage: task-log-start.sh <ITEM_ID> <CHANNEL_ID> <DESCRIPTION>
# Appends an in_progress entry so PM can detect incomplete work on resume.
# Call this at the start of any engineer queue item (after claiming, before work).

set -euo pipefail

REGISTRY_FILE="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
ITEM_ID="${1:-}"
CHANNEL_ID="${2:-unknown}"
DESCRIPTION="${3:-}"

if [[ -z "$ITEM_ID" ]]; then
  echo "Usage: task-log-start.sh <ITEM_ID> <CHANNEL_ID> <DESCRIPTION>" >&2
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
    'channel_id': '$CHANNEL_ID',
    'description': $(python3 -c "import json,sys; print(json.dumps('$DESCRIPTION'))")
}
open(f, 'a').write(json.dumps(entry) + '\n')
print('task-log-start: $ITEM_ID started at $STARTED_AT')
"
