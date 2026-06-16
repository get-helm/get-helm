#!/bin/bash
# marvin-discord-heartbeat.sh — hourly "still alive" ping to #pap-status
# Posts once and pins the message; subsequent runs PATCH it in-place.
# Run via launchd com.pap.marvin.heartbeat every 3600s

PAP_STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
PIN_ID_FILE="/Users/{{USER_HOME}}/marvin-bot/.pap-status-pin-id"
LOG="/Users/{{USER_HOME}}/marvin-bot/marvin-discord-heartbeat.log"
TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M UTC")

DISCORD_BOT_TOKEN=$(grep '^DISCORD_BOT_TOKEN=' /Users/{{USER_HOME}}/marvin-bot/.env | cut -d'=' -f2-)

if [ -z "$DISCORD_BOT_TOKEN" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: token not found in .env" >> "$LOG"
  exit 1
fi

# Check if bot.js is actually running before claiming "online"
if pgrep -f "node bot.js" > /dev/null 2>&1; then
  MESSAGE="💓 Marvin online — ${TIMESTAMP}"
else
  MESSAGE="⚠️ Marvin is down — ${TIMESTAMP} (bot.js not running)"
fi

# If we have a pinned message ID, patch it in-place; otherwise post + pin
if [ -f "$PIN_ID_FILE" ]; then
  PINNED_MSG_ID=$(cat "$PIN_ID_FILE")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
    "https://discord.com/api/v10/channels/${PAP_STATUS_CHANNEL}/messages/${PINNED_MSG_ID}" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"${MESSAGE}\"}")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] patched pinned message ${PINNED_MSG_ID} HTTP ${HTTP_CODE} — ${MESSAGE}" >> "$LOG"
    exit 0
  else
    # Pin might have been deleted; fall through to create a new one
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] patch failed HTTP ${HTTP_CODE}, re-creating pin" >> "$LOG"
    rm -f "$PIN_ID_FILE"
  fi
fi

# Post a new message
RESPONSE=$(curl -s -X POST \
  "https://discord.com/api/v10/channels/${PAP_STATUS_CHANNEL}/messages" \
  -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"${MESSAGE}\"}")

MSG_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)

if [ -z "$MSG_ID" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR posting message, response: $RESPONSE" >> "$LOG"
  exit 1
fi

# Pin the new message
PIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  "https://discord.com/api/v10/channels/${PAP_STATUS_CHANNEL}/pins/${MSG_ID}" \
  -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
  -H "Content-Length: 0")

echo "$MSG_ID" > "$PIN_ID_FILE"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] posted + pinned msg ${MSG_ID} (pin HTTP ${PIN_CODE}) — ${MESSAGE}" >> "$LOG"
