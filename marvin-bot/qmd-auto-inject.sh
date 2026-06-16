#!/bin/bash
# qmd-auto-inject.sh — auto-inject QMD top-3 context at agent spawn
# Called by bot.js before launching any agent
# Arg 1: channel_id | Arg 2: thread content or message preview (optional)

set -e
CHANNEL_ID="$1"
CONTEXT="${2:-(no context provided)}"
QMD_SCRIPT="$HOME/marvin-bot/qmd-query.sh"

# Derive query from channel name (map channel_id to human-readable context)
case "$CHANNEL_ID" in
  {{USER_CHANNEL_HELM_AUDIT}}) QUERY="HELM system audit recent activity" ;;
  {{USER_CHANNEL_HELM_IMPROVEMENTS}}) QUERY="HELM product improvements prioritized next" ;;
  1514888771873800252) QUERY="PM work automation intelligence" ;;
  1499287733007421611) QUERY="captured insights QMD second brain" ;;
  *) QUERY="$CONTEXT" ;;
esac

# Run QMD query, return structured output
if [ -x "$QMD_SCRIPT" ]; then
  RESULTS=$("$QMD_SCRIPT" "$QUERY" 3 --min-relevance 0.7 2>/dev/null || echo "[]")

  # Log to tool-usage.log
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] qmd-auto-inject: channel=$CHANNEL_ID query='$QUERY' results=$(echo "$RESULTS" | grep -c '"source"' || echo 0)" >> ~/helm-workspace/system/tool-usage.log

  # Output JSON for bot.js to inject
  echo "$RESULTS"
else
  echo "[]"
fi
