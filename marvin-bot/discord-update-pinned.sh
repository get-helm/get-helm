#!/bin/bash
# discord-update-pinned.sh — post or edit a pinned message in a Discord channel
# Usage: discord-update-pinned.sh CHANNEL_ID "message text" STATE_FILE
#   STATE_FILE: path to a file storing the pinned message ID (persists across runs)
#   First run: posts new message + pins it + saves ID to STATE_FILE
#   Subsequent runs: edits the existing pinned message in-place

CHANNEL_ID="$1"
MESSAGE="$2"
STATE_FILE="$3"

if [[ -z "$CHANNEL_ID" || -z "$MESSAGE" || -z "$STATE_FILE" ]]; then
  echo "Usage: discord-update-pinned.sh CHANNEL_ID 'message text' STATE_FILE" >&2
  exit 1
fi

BOT_TOKEN="${DISCORD_BOT_TOKEN}"
if [[ -z "$BOT_TOKEN" ]]; then
  BOT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" ~/marvin-bot/.env 2>/dev/null | cut -d= -f2-)
fi
if [[ -z "$BOT_TOKEN" ]]; then
  echo "discord-update-pinned.sh: DISCORD_BOT_TOKEN not set" >&2
  exit 1
fi

API="https://discord.com/api/v10"

_escape_json() {
  printf '%s' "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))"
}

MSG_JSON=$(_escape_json "$MESSAGE")

if [[ -f "$STATE_FILE" ]]; then
  EXISTING_ID=$(cat "$STATE_FILE" | tr -d '[:space:]')
fi

if [[ -n "$EXISTING_ID" ]]; then
  # Try editing the existing message
  RESULT=$(curl -s -w "\n%{http_code}" -X PATCH \
    -H "Authorization: Bot $BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $MSG_JSON}" \
    "$API/channels/$CHANNEL_ID/messages/$EXISTING_ID")
  HTTP_CODE=$(echo "$RESULT" | tail -n1)
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "discord-update-pinned.sh: edited message $EXISTING_ID in $CHANNEL_ID" >&2
    exit 0
  else
    echo "discord-update-pinned.sh: edit failed (HTTP $HTTP_CODE), will repost" >&2
    EXISTING_ID=""
    rm -f "$STATE_FILE"
  fi
fi

# Post new message
POST_RESULT=$(curl -s -X POST \
  -H "Authorization: Bot $BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"content\": $MSG_JSON}" \
  "$API/channels/$CHANNEL_ID/messages")

MSG_ID=$(echo "$POST_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)

if [[ -z "$MSG_ID" ]]; then
  echo "discord-update-pinned.sh: failed to post message: $POST_RESULT" >&2
  exit 1
fi

# Pin it
PIN_RESULT=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Bot $BOT_TOKEN" \
  -H "Content-Type: application/json" \
  "$API/channels/$CHANNEL_ID/pins/$MSG_ID")
PIN_CODE=$(echo "$PIN_RESULT" | tail -n1)
if [[ "$PIN_CODE" != "204" ]]; then
  echo "discord-update-pinned.sh: pin returned HTTP $PIN_CODE (non-fatal)" >&2
fi

# Save message ID
echo "$MSG_ID" > "$STATE_FILE"
echo "discord-update-pinned.sh: posted + pinned message $MSG_ID in $CHANNEL_ID" >&2
exit 0
