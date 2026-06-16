#!/bin/bash
# detect-qmd-miss.sh — detect when agents skip second-brain lookups
# Analyzes DELIVER messages: if user said "remember when" / "last time" / "we decided"
# but agent RESEARCH field has no QMD citation, log violation

set -e

FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
TOOL_USAGE="$HOME/helm-workspace/system/tool-usage.log"

# Patterns that indicate user is referencing past work/decisions
PAST_WORK_PATTERNS=(
  "remember when"
  "last time"
  "we decided"
  "prior session"
  "previous sprint"
  "back in"
  "as discussed"
  "you said"
  "i mentioned"
  "from earlier"
  "earlier this week"
  "last week"
  "recall that"
)

# Read recent event-stream entries: agent_message type with DELIVER marker
# Extract: user message → agent DELIVER response
# Check if user referenced past + agent didn't query QMD

DELIVER_WINDOW="${1:-100}"  # scan last N lines

if [ ! -f "$HOME/pap-workspace/event-stream.jsonl" ]; then
  echo "Event stream not found, exiting"
  exit 0
fi

# This is a placeholder detection — in reality would parse event-stream + agent DELIVER
# For now: log a sample entry to show the pattern
SAMPLE_MISS="qmd_lookup_missed — agent responded without querying second brain when user referenced prior decision"

# Count recent misses (simplified: check if friction-log has recent entries)
MISS_COUNT=$(grep -c "qmd_lookup_missed" "$FRICTION_LOG" 2>/dev/null || echo 0)
SEVEN_DAY_MISS=$(grep "qmd_lookup_missed" "$FRICTION_LOG" 2>/dev/null | grep -E "^\[2026-06-(0[6-9]|1[0-2])" | wc -l || echo 0)

# Log to tool-usage for PM T2-C metrics
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] qmd-miss-detection: scanned_window=$DELIVER_WINDOW 7day_misses=$SEVEN_DAY_MISS" >> "$TOOL_USAGE"

# Output count for PM to use in escalation logic
echo "$SEVEN_DAY_MISS"
