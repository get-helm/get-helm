#!/bin/bash
# log-tool-usage.sh — unified logging for tool usage (QMD, Graphify, etc.)
# Called after any tool query completes
# Arg 1: tool_name (qmd|graphify) | Arg 2: query | Arg 3: result_count

set -e

TOOL_NAME="$1"
QUERY="$2"
RESULT_COUNT="${3:-0}"
USAGE_LOG="$HOME/helm-workspace/system/tool-usage.log"

# Ensure log file exists
mkdir -p "$(dirname "$USAGE_LOG")"
touch "$USAGE_LOG"

# Append entry
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $TOOL_NAME: query='$QUERY' results=$RESULT_COUNT" >> "$USAGE_LOG"

# Trim log to last 5000 lines to prevent unbounded growth
if [ $(wc -l < "$USAGE_LOG") -gt 5000 ]; then
  tail -5000 "$USAGE_LOG" > "$USAGE_LOG.tmp"
  mv "$USAGE_LOG.tmp" "$USAGE_LOG"
fi
