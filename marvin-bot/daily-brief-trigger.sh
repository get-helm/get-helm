#!/bin/bash
# daily-brief-trigger.sh — Triggers the daily brief workspace agent via event bus
# Runs daily at 8am PT via launchd (com.pap.daily-brief.plist)
# No args needed.

EVENTS_DIR=~/helm-workspace/events
CHANNEL_ID="1504126943669260403"
TS=$(date +%s)
OUTFILE="$EVENTS_DIR/daily-brief-$TS.json"

mkdir -p "$EVENTS_DIR"

cat > "$OUTFILE" << EOF
{
  "type": "trigger_agent",
  "channel": "$CHANNEL_ID",
  "agent": "workspace:daily-brief",
  "agent_message": "[Automated daily brief] Run morning brief. Pull from three sources in parallel: (1) Gmail MCP — search unread threads from last 24 hours, subject contains any, limit 10 results; (2) Google Calendar MCP — list events for today; (3) Reddit r/churning — fetch new posts from last 24h using curl with User-Agent header. Then synthesize into Business Pulse format: three sections (📅 Calendar, 📧 Email, 💳 Credit Card Deals), max 15 lines total, no code blocks. Post as ✅ DELIVER.",
  "source": "daily-brief-cron",
  "emitted_at": $TS
}
EOF

echo "[daily-brief-trigger] Event written: $OUTFILE"
