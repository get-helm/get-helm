#!/bin/bash
# run-usage-report.sh — Combined PAP usage report
# Posts to #pap-dashboard channel
# Runs: daily (cron) or on-demand

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISCORD_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"

# 1. Try to scrape Claude.ai usage (non-fatal if fails)
echo "Running Claude.ai scraper..." >&2
SCRAPE_RESULT=$(python3 "$SCRIPT_DIR/claude-scraper.py" scrape 2>/dev/null)
SCRAPE_STATUS=$?

if [ $SCRAPE_STATUS -ne 0 ]; then
  echo "Scraper failed or no session — skipping" >&2
  echo '{"error":"scraper_failed_or_no_session"}' > "$SCRIPT_DIR/last-result.json"
fi

# 2. Run invocation report (always works)
REPORT_JSON=$(python3 "$SCRIPT_DIR/workspace-report.py" 2>/dev/null)

REPORT=$(echo "$REPORT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('report','Error generating report'))")
ALERT=$(echo "$REPORT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); a=d.get('alert'); print(a) if a else None" 2>/dev/null)

# 3. Post to Discord
"$DISCORD_POST" "$DISCORD_CHANNEL" "$REPORT"

if [ -n "$ALERT" ] && [ "$ALERT" != "None" ]; then
  "$DISCORD_POST" "$DISCORD_CHANNEL" "$ALERT"
fi

echo "Done." >&2
