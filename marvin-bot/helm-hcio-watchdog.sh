#!/usr/bin/env bash
# helm-hcio-watchdog.sh — Cross-node watchdog via HC.io API.
# Mac Mini checks VPS HC.io status every 5 min.
# If VPS is DOWN (per HC.io), posts to Discord #helm-status.
# Does NOT send email — routes through HELM Discord only.
# Cron: */5 * * * *

HC_KEY="hcw_vfqRCcqhiyqDqhNWY1P8C66pEw4P"
VPS_UUID="bf93b0da-b4b7-4339-aae0-691e5062e149"
MACMINI_UUID="355b4bf1-9601-4288-99a4-bb717e52596a"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1512683445325664356/pUCe4fp2B6IbTzy9KvMwUalGnHwj6NAAsZlRnR9w9MxQjmaR3ZTznMvHNOXQDjtvErry"
LOG="$HOME/helm-workspace/logs/hcio-watchdog.log"
STATE_FILE="$HOME/helm-workspace/.hcio-vps-alert-state"

mkdir -p "$(dirname "$LOG")"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Get VPS check status from HC.io
STATUS=$(curl -s -H "X-Api-Key: $HC_KEY" \
  "https://healthchecks.io/api/v3/checks/${VPS_UUID}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null)

if [[ "$STATUS" == "down" ]]; then
    # Only alert once per outage (not on every 5-min poll)
    LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "up")
    if [[ "$LAST_STATE" != "down" ]]; then
        # First detection — post to Discord
        curl -s -X POST "$DISCORD_WEBHOOK" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"⚠️ VPS appears offline (no ping in 10+ min). Your HELM assistant is still running on Mac Mini, but background jobs may be paused. Try waiting 5 min — if still dark, check your VPS provider console.\"}" \
          > /dev/null 2>&1
        echo "$TIMESTAMP" > "$STATE_FILE"
        echo "[$TIMESTAMP] VPS DOWN — Discord alert sent" >> "$LOG"
    fi
    echo "down" > "$STATE_FILE"
elif [[ "$STATUS" == "up" ]]; then
    LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "up")
    if [[ "$LAST_STATE" == "down" ]]; then
        # VPS came back
        curl -s -X POST "$DISCORD_WEBHOOK" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"✅ VPS is back online. All systems normal.\"}" \
          > /dev/null 2>&1
        echo "[$TIMESTAMP] VPS UP — recovery Discord alert sent" >> "$LOG"
    fi
    echo "up" > "$STATE_FILE"
else
    echo "[$TIMESTAMP] WARN: HC.io returned status='$STATUS' for VPS check" >> "$LOG"
fi
