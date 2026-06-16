#!/bin/bash
# synthesizer-backlog.sh — Flow synthesizer findings into work-items.json
# Run after synthesizer completes (or manually during PM sweep)
# Reads synthesizer-findings.md, extracts actionable items, creates work-items.json entries

set -euo pipefail

FINDINGS="$HOME/helm-workspace/system/synthesizer-findings.md"
WORK_ITEMS="$HOME/helm-workspace/work-items.json"

if [ ! -f "$FINDINGS" ]; then
  echo "[ERROR] $FINDINGS not found" >&2
  exit 1
fi

if [ ! -f "$WORK_ITEMS" ]; then
  echo "[ERROR] $WORK_ITEMS not found" >&2
  exit 1
fi

# Extract 🔴 (critical) and 🟡 (high) findings from synthesizer-findings.md
# Format: bullet + title + description
# Create work-items.json entries for each

temp_items=$(mktemp)
trap 'rm -f "$temp_items"' EXIT

# Extract critical findings (🔴)
grep -E "^🔴" "$FINDINGS" | while IFS= read -r line; do
  # Strip emoji and leading whitespace
  title=$(echo "$line" | sed 's/^🔴[[:space:]]*//; s/ —.*//')

  # Check if this finding already exists in work-items.json (by title substring match)
  if ! grep -q "\"title\": \".*$title" "$WORK_ITEMS"; then
    # Build a work-items entry
    cat >> "$temp_items" << EOF
{
  "id": "SB-$(date +%s)",
  "title": "$title",
  "description": "From synthesizer findings",
  "status": "concept",
  "priority": "critical",
  "source": "synthesizer-findings.md",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi
done

# Extract high findings (🟡)
grep -E "^🟡" "$FINDINGS" | while IFS= read -r line; do
  title=$(echo "$line" | sed 's/^🟡[[:space:]]*//; s/ —.*//')

  if ! grep -q "\"title\": \".*$title" "$WORK_ITEMS"; then
    cat >> "$temp_items" << EOF
{
  "id": "SB-$(date +%s | tail -c5)",
  "title": "$title",
  "description": "From synthesizer findings",
  "status": "concept",
  "priority": "high",
  "source": "synthesizer-findings.md",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi
done

# Log what was processed
log_line="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] synthesizer-backlog: processed findings from $FINDINGS"
if [ -s "$temp_items" ]; then
  line_count=$(wc -l < "$temp_items")
  echo "$log_line — $line_count findings not yet in backlog"
  # Could append to work-items.json here, but requires JSON-safe merging
  # For now, output to stdout so PM can review before merging
  cat "$temp_items"
else
  echo "$log_line — all findings already tracked or no new findings"
fi

echo "✓ synthesizer-backlog.sh complete"
