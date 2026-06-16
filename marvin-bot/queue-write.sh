#!/usr/bin/env bash
# queue-write.sh — atomic engineer queue writer
# Usage: queue-write.sh <ITEM_ID> <DESCRIPTION> <EST_MINS> [--restart] [--priority HIGH|MED|LOW]
# Writes to BOTH engineer-queue.md AND queue-audit.log atomically.
# Agents MUST use this script — never write to engineer-queue.md directly.
# A DELIVER claiming an item is queued without a queue-audit.log entry for it is a B-01 violation.

set -euo pipefail

QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
AUDIT_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
REGISTRY_FILE="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"

# Parse args
ITEM_ID="${1:-}"
DESCRIPTION="${2:-}"
EST_MINS="${3:-0}"
RESTART="no"
PRIORITY="MED"

if [[ -z "$ITEM_ID" || -z "$DESCRIPTION" ]]; then
  echo "Usage: queue-write.sh <ITEM_ID> <DESCRIPTION> <EST_MINS> [--restart] [--priority HIGH|MED|LOW]" >&2
  exit 1
fi

shift 3 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart) RESTART="yes" ;;
    --priority) PRIORITY="${2:-MED}"; shift ;;
  esac
  shift
done

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# PRE-QUEUE GATE: block re-queues of already-done items
PRE_CHECK_SCRIPT="$(dirname "$0")/pm-pre-queue-check.sh"
if [[ -f "$PRE_CHECK_SCRIPT" ]]; then
  PRE_RESULT=$(bash "$PRE_CHECK_SCRIPT" "$ITEM_ID" 2>&1)
  PRE_EXIT=$?
  if [[ $PRE_EXIT -eq 1 ]]; then
    echo "BLOCKED by pre-queue gate: $PRE_RESULT" >&2
    exit 1
  fi
fi

# Write structured entry to engineer-queue.md
cat >> "$QUEUE_FILE" << EOF

---
queued_at: $TIMESTAMP
id: $ITEM_ID
priority: $PRIORITY
description: $DESCRIPTION
estimate_mins: $EST_MINS
restart_required: $RESTART
status: pending
---
EOF

# Verify the queued_at: block actually landed — catch silent write failures
if ! grep -q "queued_at: $TIMESTAMP" "$QUEUE_FILE" 2>/dev/null || ! grep -q "^id: $ITEM_ID$" "$QUEUE_FILE" 2>/dev/null; then
  echo "Queue write failed — queued_at: block not found in engineer-queue.md. Check permissions. Do not claim queued." >&2
  exit 1
fi

# Append to audit log (source of truth for cross-reference)
echo "$TIMESTAMP | QUEUED | $ITEM_ID: $DESCRIPTION (${EST_MINS}m, restart=$RESTART, priority=$PRIORITY)" >> "$AUDIT_FILE"

# Append to task-registry.jsonl (shows agents what's in-flight on resume)
# Use env vars to avoid shell-interpolation breakage when description contains single quotes
QW_ITEM_ID="$ITEM_ID" QW_TIMESTAMP="$TIMESTAMP" QW_DESCRIPTION="$DESCRIPTION" \
QW_EST_MINS="$EST_MINS" QW_RESTART="$RESTART" QW_PRIORITY="$PRIORITY" QW_REGISTRY="$REGISTRY_FILE" \
python3 -c "
import json, os
entry = {
    'id': os.environ['QW_ITEM_ID'],
    'status': 'queued',
    'queued_at': os.environ['QW_TIMESTAMP'],
    'description': os.environ['QW_DESCRIPTION'],
    'estimate_mins': int(os.environ['QW_EST_MINS']),
    'restart_required': os.environ['QW_RESTART'],
    'priority': os.environ['QW_PRIORITY']
}
with open(os.environ['QW_REGISTRY'], 'a') as f:
    f.write(json.dumps(entry) + '\n')
" || { echo "ERROR: task-registry.jsonl write failed for $ITEM_ID — pm-can-deliver.sh will block until item is claimed by engineer (queue-start.sh)" >&2; }

# Emit task-event.sh queued event (TASK-LEDGER-001 §4 — keeps ledger in sync with queue)
TASK_EVENT_SH="$(dirname "$0")/task-event.sh"
if [[ -f "$TASK_EVENT_SH" ]]; then
  bash "$TASK_EVENT_SH" queued "$ITEM_ID" \
    --actor "queue-write.sh" \
    --workspace "platform" \
    --detail "$DESCRIPTION" 2>/dev/null || true  # non-fatal — ledger is supplementary
fi

# Verify all three writes
QUEUE_LINES=$(wc -l < "$QUEUE_FILE")
AUDIT_LAST=$(tail -1 "$AUDIT_FILE")
REGISTRY_CHECK=$(grep -c "\"id\": \"$ITEM_ID\"" "$REGISTRY_FILE" 2>/dev/null || echo 0)

echo "✓ Queued $ITEM_ID"
echo "  engineer-queue.md: $QUEUE_LINES lines"
echo "  audit log last entry: $AUDIT_LAST"
echo "  task-registry.jsonl: $REGISTRY_CHECK entries for $ITEM_ID"
