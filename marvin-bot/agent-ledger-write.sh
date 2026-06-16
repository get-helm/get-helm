#!/usr/bin/env bash
# agent-ledger-write.sh — append-only JSONL audit ledger for agent activity (AGENT-LEDGER-001)
# Usage: agent-ledger-write.sh <agent_name> <action> <channel_id> [message_id] [summary]
# Actions: spawn | deliver | update | block
# Writes to ~/helm-workspace/system/agent-ledger.jsonl

set -euo pipefail

LEDGER_FILE="$HOME/helm-workspace/system/agent-ledger.jsonl"
mkdir -p "$(dirname "$LEDGER_FILE")"

AGENT_NAME="${1:-unknown}"
ACTION="${2:-unknown}"
CHANNEL_ID="${3:-unknown}"
MESSAGE_ID="${4:-}"
SUMMARY="${5:-}"

if [[ -z "$AGENT_NAME" || -z "$ACTION" || -z "$CHANNEL_ID" ]]; then
  echo "Usage: agent-ledger-write.sh <agent_name> <action> <channel_id> [message_id] [summary]" >&2
  exit 1
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Write JSON line — use python3 to handle escaping cleanly
python3 -c "
import json, sys
entry = {
    'timestamp': '$TS',
    'agent_name': '$AGENT_NAME',
    'action': '$ACTION',
    'channel_id': '$CHANNEL_ID',
    'message_id': '$MESSAGE_ID',
    'summary': '$SUMMARY'
}
print(json.dumps(entry))
" >> "$LEDGER_FILE"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [ledger] $ACTION $AGENT_NAME ch=$CHANNEL_ID"
