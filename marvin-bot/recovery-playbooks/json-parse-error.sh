#!/bin/bash
# json-parse-error.sh — validate JSON files before agent reads them
# Usage: bash ~/marvin-bot/recovery-playbooks/json-parse-error.sh FILE.json [CHANNEL_ID]
# Exit 0: valid JSON. Exit 1: malformed (posts BLOCK if CHANNEL_ID provided)

FILE="$1"
CHANNEL_ID="${2:-}"

if [[ -z "$FILE" ]]; then
    echo "Usage: $0 FILE.json [CHANNEL_ID]"
    exit 2
fi

if [[ ! -f "$FILE" ]]; then
    echo "ERROR: $FILE not found"
    if [[ -n "$CHANNEL_ID" ]]; then
        source <(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env 2>/dev/null)
        curl -s -X POST \
            -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"⏸ BLOCK — required file missing: $FILE\"}" \
            "https://discord.com/api/v10/channels/$CHANNEL_ID/messages" > /dev/null 2>&1
    fi
    exit 1
fi

RESULT=$(python3 -c "
import json, sys
try:
    with open('$FILE') as f:
        json.load(f)
    print('VALID')
except json.JSONDecodeError as e:
    print(f'INVALID: {e}')
    sys.exit(1)
" 2>&1)

if echo "$RESULT" | grep -q "^INVALID"; then
    LINE=$(echo "$RESULT" | grep -oE 'line [0-9]+' | head -1)
    MSG="⏸ BLOCK — malformed JSON in $FILE ($LINE). Cannot proceed until fixed."
    echo "$MSG"
    if [[ -n "$CHANNEL_ID" ]]; then
        source <(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env 2>/dev/null)
        curl -s -X POST \
            -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$MSG\"}" \
            "https://discord.com/api/v10/channels/$CHANNEL_ID/messages" > /dev/null 2>&1
    fi
    exit 1
fi

echo "JSON valid: $FILE"
exit 0
