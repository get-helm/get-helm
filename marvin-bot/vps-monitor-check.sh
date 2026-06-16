#!/usr/bin/env bash
# vps-monitor-check.sh — polls HC.io API for VPS check status.
# Runs every 5 min via cron. Posts to Discord only if VPS is DOWN for 15+ min.
# Mac Mini runs this to catch VPS outages (VPS can't self-report when down).

set -euo pipefail

HC_API_KEY="${HELM_HC_API_KEY:-}"  # Set in .env — never hardcode
VPS_CHECK_UUID="${HELM_HC_CHECK_UUID:-}"  # Set in .env — never hardcode
DISCORD_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"  # #helm-status
DISCORD_SCRIPT="$HOME/marvin-bot/discord-post.sh"
STATE_FILE="$HOME/marvin-bot/.vps-monitor-state"
LOG="$HOME/marvin-bot/vps-monitor.log"
COOLDOWN=3600       # 1 hr between repeated DOWN alerts
DOWN_THRESHOLD=900  # 15 min before alerting (matches HC.io grace period)

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"; }

# Read current HC.io status
RESPONSE=$(curl -s -m 10 -H "X-Api-Key: $HC_API_KEY" \
  "https://healthchecks.io/api/v3/checks/$VPS_CHECK_UUID" 2>/dev/null || echo '{}')
STATUS=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
LAST_PING=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('last_ping','never'))" 2>/dev/null || echo "never")

log "VPS check status: $STATUS (last ping: $LAST_PING)"

# Load state
if [[ -f "$STATE_FILE" ]]; then
  PREV_STATUS=$(grep "^status=" "$STATE_FILE" | cut -d= -f2 || echo "up")
  FIRST_DOWN=$(grep "^first_down=" "$STATE_FILE" | cut -d= -f2 || echo "0")
  LAST_ALERTED=$(grep "^last_alerted=" "$STATE_FILE" | cut -d= -f2 || echo "0")
else
  PREV_STATUS="up"
  FIRST_DOWN=0
  LAST_ALERTED=0
fi

NOW=$(date +%s)

if [[ "$STATUS" == "up" ]]; then
  if [[ "$PREV_STATUS" == "down" || "$PREV_STATUS" == "late" ]]; then
    # VPS just recovered — post recovery notification
    log "VPS recovered. Posting recovery notification."
    "$DISCORD_SCRIPT" "$DISCORD_CHANNEL" "✅ VPS is back online. All systems normal." || true
  fi
  # Reset state
  printf "status=up\nfirst_down=0\nlast_alerted=0\n" > "$STATE_FILE"

elif [[ "$STATUS" == "down" || "$STATUS" == "late" ]]; then
  if [[ "$PREV_STATUS" == "up" ]]; then
    # First time we see DOWN — record timestamp
    FIRST_DOWN=$NOW
    log "VPS first appears DOWN at $FIRST_DOWN"
  fi

  DOWN_DURATION=$(( NOW - FIRST_DOWN ))
  SINCE_ALERTED=$(( NOW - LAST_ALERTED ))

  # First: try SSH auto-restart (catches service crashes where VM is still up)
  RESTART_ATTEMPTED_FILE="$HOME/marvin-bot/.vps-restart-attempted"
  if [[ ! -f "$RESTART_ATTEMPTED_FILE" ]] || [[ $(( NOW - $(cat "$RESTART_ATTEMPTED_FILE" 2>/dev/null || echo 0) )) -gt 3600 ]]; then
    log "Attempting SSH auto-restart before alerting..."
    if "$HOME/marvin-bot/vps-service-restart.sh" 2>/dev/null; then
      log "SSH restart succeeded — VPS services may be recovering. Waiting for next HC.io ping."
      echo "$NOW" > "$RESTART_ATTEMPTED_FILE"
      printf "status=%s\nfirst_down=%d\nlast_alerted=%d\n" "$STATUS" "$FIRST_DOWN" "$LAST_ALERTED" > "$STATE_FILE"
      exit 0  # Don't alert yet — give HC.io time to see the recovery ping
    else
      log "SSH restart failed or VM unreachable — trying Hostinger API restart"
      echo "$NOW" > "$RESTART_ATTEMPTED_FILE"
      # Second attempt: Hostinger API restart (handles full VM crash where SSH is gone)
      if "$HOME/marvin-bot/hostinger-vps-restart.sh" 2>/dev/null; then
        log "Hostinger API restart triggered — waiting for VM to come back up"
        "$DISCORD_SCRIPT" "$DISCORD_CHANNEL" "⚠️ VPS was offline — SSH unreachable. Sent a restart via Hostinger API. Should be back in 1-2 min." || true
        LAST_ALERTED=$NOW
        printf "status=%s\nfirst_down=%d\nlast_alerted=%d\n" "$STATUS" "$FIRST_DOWN" "$LAST_ALERTED" > "$STATE_FILE"
        exit 0
      else
        log "Hostinger API restart also failed — manual intervention required"
      fi
    fi
  fi

  if [[ $DOWN_DURATION -ge $DOWN_THRESHOLD && $SINCE_ALERTED -ge $COOLDOWN ]]; then
    # Sustained outage, cooldown elapsed — post to Discord
    log "VPS DOWN for ${DOWN_DURATION}s — posting to Discord."
    "$DISCORD_SCRIPT" "$DISCORD_CHANNEL" "⚠️ VPS has been offline for $(( DOWN_DURATION / 60 )) min. Auto-restart via SSH and Hostinger API both failed. Log into hpanel.hostinger.com to restart manually." || true
    LAST_ALERTED=$NOW
  fi

  printf "status=%s\nfirst_down=%d\nlast_alerted=%d\n" "$STATUS" "$FIRST_DOWN" "$LAST_ALERTED" > "$STATE_FILE"
fi
