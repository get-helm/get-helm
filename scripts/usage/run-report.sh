#!/usr/bin/env bash
# Run usage report and post to Discord.
# Usage: run-report.sh [channel_id]
# If no channel_id given, posts to #pap-dashboard.

CHANNEL="${1:-{{USER_CHANNEL_HELM_STATUS}}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

result=$(python3 "$SCRIPT_DIR/workspace-report.py" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$result" ]; then
  ~/marvin-bot/discord-post.sh "$CHANNEL" "⚠️ Usage report failed to run — check ~/pap-workspace/scripts/usage/"
  exit 1
fi

report=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['report'])")
alert=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); a=d.get('alert'); print(a) if a else print('')" 2>/dev/null)
sonnet_alert=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); a=d.get('sonnet_alert'); print(a) if a else print('')" 2>/dev/null)

if [ -n "$alert" ]; then
  ~/marvin-bot/discord-post.sh "$CHANNEL" "$alert"
fi

if [ -n "$sonnet_alert" ]; then
  ~/marvin-bot/discord-post.sh "$CHANNEL" "$sonnet_alert"
fi

~/marvin-bot/discord-post.sh "$CHANNEL" "$report"
