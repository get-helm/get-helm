#!/usr/bin/env bash
# vps-health-monitor.sh — Mac Mini pings VPS health every 5 min.
# Tracks consecutive failures; posts BLOCK to #pap-improvements on 2+ failures.
# State file: ~/helm-workspace/.vps-health-state.json

set -euo pipefail

STATE_FILE="$HOME/helm-workspace/.vps-health-state.json"
LOG_FILE="$HOME/helm-workspace/logs/vps-health.log"
VPS_HEALTH_URL="http://{{USER_VPS_TAILSCALE_IP}}:9876/status"
VPS_STATUS_URL="https://status.{{USER_DOMAIN}}"
ALERT_THRESHOLD=2  # consecutive failures before posting to Discord

# Read .env for DISCORD_BOT_TOKEN
if [[ -f "$HOME/marvin-bot/.env" ]]; then
  export $(grep -E "^DISCORD_BOT_TOKEN=" "$HOME/marvin-bot/.env" || true)
fi

PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
mkdir -p "$(dirname "$LOG_FILE")"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current state
FAILURES=0
LAST_ALERT=""
if [[ -f "$STATE_FILE" ]]; then
  FAILURES=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('consecutive_failures', 0))" 2>/dev/null || echo 0)
  LAST_ALERT=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('last_alert_at', ''))" 2>/dev/null || echo "")
fi

# Ping VPS health endpoint (Tailscale IP)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 8 "$VPS_HEALTH_URL" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
  # VPS healthy — reset counter
  if [[ "$FAILURES" -gt 0 ]]; then
    echo "[$TIMESTAMP] VPS recovered after $FAILURES consecutive failures" >> "$LOG_FILE"
    # Post recovery notice to Discord
    if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
      curl -s -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"✅ VPS health restored — ${FAILURES} consecutive failures cleared. VPS responding at $TIMESTAMP.\"}" \
        "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" > /dev/null 2>&1 || true
    fi
  fi
  python3 -c "import json; json.dump({'consecutive_failures': 0, 'last_check': '$TIMESTAMP', 'last_status': 'ok', 'last_alert_at': '$LAST_ALERT'}, open('$STATE_FILE', 'w'))" 2>/dev/null || true
  echo "[$TIMESTAMP] VPS healthy (HTTP $HTTP_CODE)" >> "$LOG_FILE"
else
  # VPS unreachable
  FAILURES=$((FAILURES + 1))
  echo "[$TIMESTAMP] VPS unreachable (HTTP $HTTP_CODE, failure #$FAILURES)" >> "$LOG_FILE"
  python3 -c "import json; json.dump({'consecutive_failures': $FAILURES, 'last_check': '$TIMESTAMP', 'last_status': 'failed', 'last_http': '$HTTP_CODE', 'last_alert_at': '$LAST_ALERT'}, open('$STATE_FILE', 'w'))" 2>/dev/null || true

  if [[ "$FAILURES" -ge "$ALERT_THRESHOLD" ]]; then
    # Check if we already alerted within the last 30 min (avoid spam)
    NOW_EPOCH=$(date +%s)
    ALERT_EPOCH=0
    if [[ -n "$LAST_ALERT" ]]; then
      ALERT_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_ALERT" +%s 2>/dev/null || echo 0)
    fi
    ELAPSED=$(( NOW_EPOCH - ALERT_EPOCH ))

    if [[ "$ELAPSED" -gt 1800 ]] && [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
      echo "[$TIMESTAMP] Posting VPS failure alert ($FAILURES consecutive failures)" >> "$LOG_FILE"
      curl -s -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"⏸ VPS health BLOCK — $FAILURES consecutive failures. VPS unreachable at $VPS_HEALTH_URL. Check status at $VPS_STATUS_URL or SSH to {{USER_VPS_IP}}.\"}" \
        "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" > /dev/null 2>&1 || true
      # Update last_alert_at
      python3 -c "import json; d=json.load(open('$STATE_FILE')); d['last_alert_at']='$TIMESTAMP'; json.dump(d, open('$STATE_FILE','w'))" 2>/dev/null || true
    fi
  fi
fi
