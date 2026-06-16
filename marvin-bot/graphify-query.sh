#!/bin/bash
# graphify-query.sh — Query the code knowledge graph instead of reading full files
# Usage: graphify-query.sh "symbol_or_function_name" [graph.json path]
# Output: node definition + call connections (~500 tokens vs ~65k for full bot.js read)
# Use BEFORE reading any file >500 lines to answer "where is X?" / "what calls Y?"

TERM_Q="$1"
GRAPH="${2:-$HOME/marvin-bot/graphify-out/graph.json}"
GRAPHIFY="$HOME/.local/bin/graphify"

if [[ -z "$TERM_Q" ]]; then
  echo "usage: graphify-query.sh \"symbol_name\" [graph.json]" >&2
  exit 1
fi

if [[ ! -x "$GRAPHIFY" ]]; then
  echo "graphify binary not found at $GRAPHIFY" >&2
  exit 1
fi

if [[ ! -f "$GRAPH" ]]; then
  echo "graph not found at $GRAPH — run weekly reindex or check launchd job" >&2
  exit 1
fi

# Usage telemetry — PM T2-C reads weekly counts to measure adoption
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] graphify-query q=\"$TERM_Q\"" >> ~/helm-workspace/system/tool-usage.log 2>/dev/null

"$GRAPHIFY" explain "$TERM_Q" --graph "$GRAPH"
