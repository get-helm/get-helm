#!/bin/bash
# self-improve.sh — P2.7: PAP self-improvement loop
# Creates git snapshots, logs changes, and provides rollback for agent .md file modifications.
# Scope: ~/.claude/agents/*.md only. Never bot.js, never turn-protocol.md, never CLAUDE.md.
#
# Commands:
#   self-improve.sh snapshot <label>                              — create git tag, print tag name
#   self-improve.sh log <pattern> <file> <tag> "<description>"   — record what was changed
#   self-improve.sh rollback <tag> <agent_file>                  — revert agent file to snapshot
#   self-improve.sh check <pattern> [lookback_minutes]           — check if pattern still recurring (exit 0=clear, 1=recurring)
#   self-improve.sh status                                        — show recent self-improve log entries

set -euo pipefail

PAP_CONFIG="$HOME/helm-config"
AGENTS_LIVE="$HOME/.claude/agents"
LOG_FILE="$HOME/helm-workspace/self-improve-log.jsonl"
FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
NO_TOUCH_FILES=("turn-protocol.md" "CLAUDE.md" "bot.js" "pap-complete.md" "pap-all-workflows.md")

COMMAND="${1:-status}"

# Safety: never touch protected files
check_safe_target() {
  local file="$1"
  local basename
  basename="$(basename "$file")"
  for protected in "${NO_TOUCH_FILES[@]}"; do
    if [[ "$basename" == "$protected" ]]; then
      echo "ERROR: $basename is a protected file — self-improve.sh never touches it." >&2
      exit 2
    fi
  done
}

case "$COMMAND" in

  snapshot)
    LABEL="${2:-auto}"
    TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
    TAG="self-improve-${TIMESTAMP}-${LABEL}"

    # Sync current live agents to pap-config before tagging
    for AGENT_FILE in "$AGENTS_LIVE"/*.md; do
      BASENAME=$(basename "$AGENT_FILE")
      DEST="$PAP_CONFIG/agents/$BASENAME"
      if [ -f "$DEST" ]; then
        cp "$AGENT_FILE" "$DEST"
      fi
    done

    # Commit any changes + create tag
    cd "$PAP_CONFIG"
    if ! git diff --quiet agents/ 2>/dev/null; then
      git add agents/
      git commit -m "Self-improve snapshot: $LABEL (pre-change state)" 2>/dev/null
    fi

    git tag "$TAG" 2>/dev/null || true
    git push origin "$TAG" 2>/dev/null || true

    echo "$TAG"
    ;;

  log)
    PATTERN="${2:-unknown}"
    AGENT_FILE="${3:-unknown}"
    SNAPSHOT_TAG="${4:-none}"
    DESCRIPTION="${5:-no description}"
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    mkdir -p "$(dirname "$LOG_FILE")"
    echo "{\"ts\":\"$TS\",\"pattern\":\"$PATTERN\",\"agent_file\":\"$AGENT_FILE\",\"snapshot_tag\":\"$SNAPSHOT_TAG\",\"description\":\"$DESCRIPTION\",\"status\":\"applied\"}" >> "$LOG_FILE"
    echo "Logged: $PATTERN → $AGENT_FILE (snapshot: $SNAPSHOT_TAG)"
    ;;

  rollback)
    SNAPSHOT_TAG="${2:-}"
    AGENT_FILE="${3:-}"

    if [ -z "$SNAPSHOT_TAG" ] || [ -z "$AGENT_FILE" ]; then
      echo "Usage: self-improve.sh rollback <tag> <agent_filename>" >&2
      exit 1
    fi

    check_safe_target "$AGENT_FILE"
    BASENAME=$(basename "$AGENT_FILE")

    # Get file at snapshot tag from pap-config
    cd "$PAP_CONFIG"
    SNAPSHOT_CONTENT=$(git show "${SNAPSHOT_TAG}:agents/${BASENAME}" 2>/dev/null) || {
      echo "ERROR: Cannot find $BASENAME in snapshot $SNAPSHOT_TAG" >&2
      exit 3
    }

    # Write back to live agents
    echo "$SNAPSHOT_CONTENT" > "$AGENTS_LIVE/$BASENAME"

    # Also update pap-config
    echo "$SNAPSHOT_CONTENT" > "$PAP_CONFIG/agents/$BASENAME"
    git add "agents/$BASENAME"
    git commit -m "Self-improve rollback: $BASENAME to $SNAPSHOT_TAG" 2>/dev/null
    git push origin main 2>/dev/null || true

    # Log rollback
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"ts\":\"$TS\",\"action\":\"rollback\",\"agent_file\":\"$BASENAME\",\"snapshot_tag\":\"$SNAPSHOT_TAG\",\"status\":\"rolled_back\"}" >> "$LOG_FILE"
    echo "Rolled back $BASENAME to $SNAPSHOT_TAG"
    ;;

  check)
    PATTERN="${2:-}"
    LOOKBACK_MIN="${3:-30}"

    if [ -z "$PATTERN" ] || [ ! -f "$FRICTION_LOG" ]; then
      exit 0
    fi

    # Count occurrences of pattern in friction-log from last N minutes
    CUTOFF=$(date -u -v-"${LOOKBACK_MIN}"M +%Y-%m-%dT%H:%M 2>/dev/null || date -u --date="${LOOKBACK_MIN} minutes ago" +%Y-%m-%dT%H:%M 2>/dev/null || echo "2000-01-01T00:00")

    COUNT=$(python3 - "$FRICTION_LOG" "$PATTERN" "$CUTOFF" << 'PYEOF'
import sys, re

log_file = sys.argv[1]
pattern = sys.argv[2].upper()
cutoff = sys.argv[3]

count = 0
with open(log_file) as f:
    for line in f:
        ts_match = re.search(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})', line)
        if ts_match and ts_match.group(1) >= cutoff:
            if pattern in line.upper():
                count += 1
print(count)
PYEOF
)

    echo "Pattern '$PATTERN' occurrences in last ${LOOKBACK_MIN}min: $COUNT"
    # Exit 1 if still recurring (2+), 0 if clear
    [ "$COUNT" -lt 2 ]
    ;;

  status)
    if [ ! -f "$LOG_FILE" ]; then
      echo "No self-improve log found."
      exit 0
    fi
    echo "Recent self-improve actions:"
    tail -5 "$LOG_FILE" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        action = e.get('action', 'applied')
        print(f\"  {e.get('ts','')} [{action}] {e.get('pattern', e.get('agent_file','?'))}\")
    except:
        pass
"
    ;;

  *)
    echo "Usage: self-improve.sh <snapshot|log|rollback|check|status> [args...]" >&2
    exit 1
    ;;
esac
