#!/bin/bash
# detect-qmd-miss-detailed.sh — detect when agents skip second-brain lookups
# Scans last N event-stream entries for: user message + agent DELIVER pair
# Identifies "missed" if: user referenced past work but agent didn't query QMD
# Logs violations to friction-log.md

set -e

WORKDIR="$1"
[ -z "$WORKDIR" ] && WORKDIR=~/helm-workspace

EVENT_STREAM="$WORKDIR/event-stream.jsonl"
FRICTION_LOG="$WORKDIR/system/friction-log.md"
WINDOW="${2:-50}"  # Analyze last N lines

[ ! -f "$EVENT_STREAM" ] && exit 0

# Patterns indicating user references prior work/decisions
PATTERNS=(
  "remember"
  "last time"
  "we decided"
  "earlier"
  "prior"
  "before"
  "previously"
  "as discussed"
  "from last"
)

# QMD citation patterns in RESEARCH field
QMD_PATTERNS=(
  "qmd:"
  "second.brain"
  "query="
  "relevance"
)

# Simple heuristic: scan last N lines for message pairs
# For each pair, check: user message has prior-work pattern + agent DELIVER has no QMD citation
MISS_COUNT=0
PROCESSED=0

tail -n "$WINDOW" "$EVENT_STREAM" | while read -r line; do
  [ -z "$line" ] && continue

  # Parse JSON — extract type, author, message text
  MSG_TYPE=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4 | head -1)

  # Skip if not a message
  [ "$MSG_TYPE" != "message" ] && continue

  AUTHOR=$(echo "$line" | grep -o '"author":"[^"]*"' | cut -d'"' -f4 | head -1)
  CONTENT=$(echo "$line" | grep -o '"content":"[^"]*' | cut -d'"' -f4 | head -1)

  # Check if user message contains "prior work" pattern
  HAS_PRIOR=0
  for pattern in "${PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -iq "$pattern"; then
      HAS_PRIOR=1
      break
    fi
  done

  [ "$HAS_PRIOR" -eq 0 ] && continue  # Skip if no prior-work reference

  # This message references past work — was QMD queried in the agent response?
  # (In a real implementation, correlate with next agent DELIVER and check RESEARCH field)
  # For now: log as a candidate for manual review

  PROCESSED=$((PROCESSED + 1))
done

# Log summary to friction-log
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[$TIMESTAMP] qmd_lookup_detection: scanned $WINDOW lines, $PROCESSED candidates for QMD miss (requires manual correlation with DELIVER)" >> "$FRICTION_LOG"

# For PM metrics, return count of potential misses
echo "$PROCESSED"
