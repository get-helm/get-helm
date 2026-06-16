#!/bin/bash
# regex-safe-check.sh — safe grep/sed wrapper with timeout and empty-match guard
# Usage: bash ~/marvin-bot/recovery-playbooks/regex-safe-check.sh PATTERN FILE [CHANNEL_ID]
# Exit 0: matches found. Exit 1: no match or error (posts warning if CHANNEL_ID provided)

PATTERN="$1"
FILE="$2"
CHANNEL_ID="${3:-}"
TIMEOUT_SECS=10

if [[ -z "$PATTERN" || -z "$FILE" ]]; then
    echo "Usage: $0 PATTERN FILE [CHANNEL_ID]"
    exit 2
fi

if [[ ! -f "$FILE" ]]; then
    echo "ERROR: $FILE not found"
    exit 1
fi

# Run grep with timeout
RESULT=$(timeout "$TIMEOUT_SECS" grep -E "$PATTERN" "$FILE" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 124 ]]; then
    MSG="⚠️ regex-safe-check: grep timed out after ${TIMEOUT_SECS}s on $FILE (pattern: $PATTERN)"
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

if [[ $EXIT_CODE -ne 0 || -z "$RESULT" ]]; then
    MSG="⚠️ regex-safe-check: no matches for pattern '$PATTERN' in $FILE"
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

echo "$RESULT"
exit 0
