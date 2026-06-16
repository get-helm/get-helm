#!/bin/bash
# discord-create-thread.sh — post a message to a channel and create a thread from it
# Usage: discord-create-thread.sh CHANNEL_ID "Thread Name" "Seed message text"
# Returns: the thread channel ID on success, empty on failure

CHANNEL_ID="$1"
THREAD_NAME="$2"
SEED_MSG="$3"

if [[ -z "$CHANNEL_ID" || -z "$THREAD_NAME" || -z "$SEED_MSG" ]]; then
  echo "Usage: discord-create-thread.sh CHANNEL_ID 'Thread Name' 'Seed message'" >&2
  exit 1
fi

BOT_TOKEN="${DISCORD_BOT_TOKEN}"
if [[ -z "$BOT_TOKEN" ]]; then
  BOT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" ~/marvin-bot/.env 2>/dev/null | cut -d= -f2-)
fi
if [[ -z "$BOT_TOKEN" ]]; then
  echo "discord-create-thread.sh: DISCORD_BOT_TOKEN not set" >&2
  exit 1
fi

# Read active palette
VS_FILE=~/helm-workspace/VOICE-AND-STYLE.md
PRIMARY=$(grep "^COLOR_PRIMARY=" "$VS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo "#7C3AED")
HEX="${PRIMARY/#\#/}"
COLOR=$((16#${HEX}))

# Step 1: Post a message to anchor the thread
JSON_MSG=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$SEED_MSG")
PAYLOAD="{\"embeds\":[{\"color\":${COLOR},\"description\":${JSON_MSG}}]}"

TMPFILE=$(mktemp)
HTTP=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
  -H "Authorization: Bot ${BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$HTTP" != "200" ]]; then
  echo "discord-create-thread.sh: message post HTTP $HTTP" >&2
  rm -f "$TMPFILE"
  exit 1
fi

MSG_ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('id',''))" "$TMPFILE")
rm -f "$TMPFILE"

if [[ -z "$MSG_ID" ]]; then
  echo "discord-create-thread.sh: could not get message ID" >&2
  exit 1
fi

# Step 2: Create a thread from that message
THREAD_PAYLOAD="{\"name\":\"$(echo "$THREAD_NAME" | head -c 100)\",\"auto_archive_duration\":1440}"
TFILE=$(mktemp)
THTTP=$(curl -s -o "$TFILE" -w "%{http_code}" \
  -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages/${MSG_ID}/threads" \
  -H "Authorization: Bot ${BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$THREAD_PAYLOAD")

if [[ "$THTTP" != "200" && "$THTTP" != "201" ]]; then
  echo "discord-create-thread.sh: thread create HTTP $THTTP — $(cat "$TFILE")" >&2
  rm -f "$TFILE"
  exit 1
fi

THREAD_ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('id',''))" "$TFILE")
rm -f "$TFILE"

echo "$THREAD_ID"
