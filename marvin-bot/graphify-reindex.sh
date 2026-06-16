#!/usr/bin/env bash
# graphify-reindex.sh — Rebuild PAP knowledge graphs for token-efficient code queries
# Runs Sundays at 3am PT via com.pap.graphify-reindex launchd plist.
# Can also be run manually: bash ~/marvin-bot/graphify-reindex.sh
#
# Outputs:
#   ~/marvin-bot/graphify-out/graph.json  — bot.js + scripts (603+ nodes)
#   ~/.claude/agents/graphify-out/graph.json — agent .md files (490+ nodes)

set -euo pipefail

GRAPHIFY="$HOME/.local/bin/graphify"
LOG="$HOME/marvin-bot/marvin.log"
MARVIN_BOT="$HOME/marvin-bot"
AGENTS_DIR="$HOME/.claude/agents"
PAP_AUDIT="{{USER_CHANNEL_HELM_AUDIT}}"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [graphify-reindex] $*" | tee -a "$LOG"
}

log "Starting graphify re-index (marvin-bot + agents)"

# Re-index marvin-bot (bot.js + scripts)
log "Extracting marvin-bot..."
cd "$MARVIN_BOT"
UPDATE_OUT=$("$GRAPHIFY" update . --no-cluster 2>&1)
echo "$UPDATE_OUT" | tail -3 | while IFS= read -r line; do log "$line"; done

MARVIN_GRAPH="$MARVIN_BOT/graphify-out/graph.json"
if [[ ! -f "$MARVIN_GRAPH" ]]; then
  log "ERROR: marvin-bot graph not found at $MARVIN_GRAPH"
  exit 1
fi
BOTJS_NODES=$(python3 -c "import json; g=json.load(open('$MARVIN_GRAPH')); print(len(g['nodes']))" 2>/dev/null || echo "?")
log "marvin-bot indexed: $BOTJS_NODES nodes"

# Re-index agent .md files
log "Extracting agent files..."
cd "$AGENTS_DIR"
UPDATE_OUT=$("$GRAPHIFY" update . --no-cluster 2>&1)
echo "$UPDATE_OUT" | tail -3 | while IFS= read -r line; do log "$line"; done

AGENTS_GRAPH="$AGENTS_DIR/graphify-out/graph.json"
if [[ ! -f "$AGENTS_GRAPH" ]]; then
  log "ERROR: agents graph not found at $AGENTS_GRAPH"
  exit 1
fi
AGENT_NODES=$(python3 -c "import json; g=json.load(open('$AGENTS_GRAPH')); print(len(g['nodes']))" 2>/dev/null || echo "?")
log "agents indexed: $AGENT_NODES nodes"

log "Re-index complete. marvin-bot=$BOTJS_NODES nodes, agents=$AGENT_NODES nodes"

# Notify pap-audit
if [[ -f "$DISCORD_POST" ]]; then
  source "$MARVIN_BOT/.env" 2>/dev/null || true
  "$DISCORD_POST" "$PAP_AUDIT" "🔗 graphify-reindex — marvin-bot=${BOTJS_NODES} nodes, agents=${AGENT_NODES} nodes" 2>/dev/null || true
fi
