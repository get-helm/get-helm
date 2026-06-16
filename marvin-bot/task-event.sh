#!/usr/bin/env bash
# task-event.sh — unified task lifecycle ledger (TASK-LEDGER-001 Phase 1)
# Usage: task-event.sh <event_type> <task_id> [options]
#
# Event types: created | spec_written | approved | queued | picked_up | progress |
#              blocked | unblocked | done_claimed | verified | shelved | reopened
#
# Options:
#   --actor <name>       agent or user writing the event (default: caller env or "agent")
#   --workspace <name>   platform | etf-tracker | options-helper | etc (default: platform)
#   --detail <text>      human description of what happened
#   --evidence <ref>     file:line or log ref (REQUIRED for done_claimed + verified)
#
# Writes atomically to system/task-ledger.jsonl via flock.
# Validates state transitions before appending.

set -euo pipefail

LEDGER_FILE="$HOME/helm-workspace/system/task-ledger.jsonl"

EVENT_TYPE="${1:-}"
TASK_ID="${2:-}"
ACTOR="${ENGINEER_AGENT:-agent}"
WORKSPACE="platform"
DETAIL=""
EVIDENCE=""

if [[ -z "$EVENT_TYPE" || -z "$TASK_ID" ]]; then
  echo "Usage: task-event.sh <event_type> <task_id> [--actor name] [--workspace name] [--detail text] [--evidence ref]" >&2
  echo "Event types: created spec_written approved queued picked_up progress blocked unblocked done_claimed verified shelved reopened" >&2
  exit 1
fi

shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor)     ACTOR="${2:-}"; shift 2 ;;
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --detail)    DETAIL="${2:-}"; shift 2 ;;
    --evidence)  EVIDENCE="${2:-}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate event type
VALID_EVENTS="created spec_written approved queued picked_up progress blocked unblocked done_claimed verified shelved reopened"
if ! echo "$VALID_EVENTS" | grep -qw "$EVENT_TYPE"; then
  echo "ERROR: Invalid event type '$EVENT_TYPE'. Valid: $VALID_EVENTS" >&2
  exit 1
fi

# Require evidence for done_claimed and verified
if [[ "$EVENT_TYPE" == "done_claimed" || "$EVENT_TYPE" == "verified" ]]; then
  if [[ -z "$EVIDENCE" ]]; then
    echo "ERROR: --evidence is required for $EVENT_TYPE (file:line, commit hash, or test output)" >&2
    exit 1
  fi
fi

# Validate state transition — get last event for this task_id
LAST_EVENT=""
if [[ -f "$LEDGER_FILE" ]]; then
  LAST_EVENT=$(python3 -c "
import json, sys
task_id = sys.argv[1]
last = None
try:
    with open('$LEDGER_FILE') as f:
        for line in f:
            try:
                e = json.loads(line.strip())
                if e.get('task_id') == task_id:
                    last = e.get('event', '')
            except: pass
except: pass
print(last or '')
" "$TASK_ID" 2>/dev/null || echo "")
fi

# Transition guard — catch obviously wrong sequences
validate_transition() {
  local from="$1" to="$2"
  case "$to" in
    done_claimed)
      if [[ "$from" == "done_claimed" || "$from" == "verified" || "$from" == "shelved" ]]; then
        echo "ERROR: Cannot transition from '$from' to 'done_claimed'" >&2; exit 1
      fi ;;
    verified)
      if [[ "$from" != "done_claimed" ]]; then
        echo "ERROR: 'verified' must follow 'done_claimed' (current: '$from')" >&2; exit 1
      fi ;;
    picked_up)
      if [[ "$from" == "done_claimed" || "$from" == "verified" || "$from" == "shelved" ]]; then
        echo "ERROR: Cannot transition from '$from' to 'picked_up'" >&2; exit 1
      fi ;;
    created)
      if [[ -n "$from" ]]; then
        echo "ERROR: 'created' can only be the first event for a task (current: '$from')" >&2; exit 1
      fi ;;
  esac
}

validate_transition "$LAST_EVENT" "$EVENT_TYPE"

# Build JSON event
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Escape strings for JSON
json_escape() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" <<< "$1"
}

DETAIL_JSON=$(json_escape "$DETAIL")
EVIDENCE_JSON=$(json_escape "$EVIDENCE")
ACTOR_JSON=$(json_escape "$ACTOR")
WORKSPACE_JSON=$(json_escape "$WORKSPACE")
TASK_ID_JSON=$(json_escape "$TASK_ID")
EVENT_TYPE_JSON=$(json_escape "$EVENT_TYPE")

JSON_LINE="{\"ts\":\"$TIMESTAMP\",\"task_id\":$TASK_ID_JSON,\"event\":$EVENT_TYPE_JSON,\"actor\":$ACTOR_JSON,\"workspace\":$WORKSPACE_JSON,\"detail\":$DETAIL_JSON,\"evidence\":$EVIDENCE_JSON}"

# Validate JSON before appending
echo "$JSON_LINE" | python3 -c "import json,sys; json.load(sys.stdin); print('json ok')" 2>/dev/null || {
  echo "ERROR: JSON validation failed for event: $JSON_LINE" >&2; exit 1
}

# Atomic append with fcntl.flock via Python (macOS-compatible, prevents concurrent corruption)
mkdir -p "$(dirname "$LEDGER_FILE")"
python3 << PYEOF
import fcntl, os, sys

ledger = os.path.expanduser("$LEDGER_FILE")
lock_file = ledger + ".lock"
line = """$JSON_LINE"""

try:
    with open(lock_file, 'w') as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        with open(ledger, 'a') as f:
            f.write(line + "\n")
        fcntl.flock(lf, fcntl.LOCK_UN)
except Exception as e:
    print(f"ERROR: Could not write to {ledger}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

echo "✓ task-event: $TASK_ID $EVENT_TYPE at $TIMESTAMP"
if [[ -n "$DETAIL" ]]; then echo "  detail: $DETAIL"; fi
if [[ -n "$EVIDENCE" ]]; then echo "  evidence: $EVIDENCE"; fi

# Regenerate TASK-BOARD.md in the background after every ledger write (TASK-LEDGER-002)
BOARD_GEN="$(dirname "$0")/generate-task-board.sh"
if [[ -x "$BOARD_GEN" ]]; then
  "$BOARD_GEN" > /dev/null 2>&1 &
fi
