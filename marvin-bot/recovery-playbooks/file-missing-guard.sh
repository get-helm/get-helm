#!/bin/bash
# file-missing-guard.sh — check required files exist before workspace agent runs
# Usage: bash ~/marvin-bot/recovery-playbooks/file-missing-guard.sh CHANNEL_ID FILE1 FILE2 ...
# Exit 0: all files present. Exit 1: missing file(s) — posts BLOCK with specific path

CHANNEL_ID="$1"
shift
REQUIRED_FILES=("$@")

if [[ -z "$CHANNEL_ID" || ${#REQUIRED_FILES[@]} -eq 0 ]]; then
    echo "Usage: $0 CHANNEL_ID FILE1 [FILE2 ...]"
    exit 2
fi

MISSING=()
for F in "${REQUIRED_FILES[@]}"; do
    EXPANDED="${F/#\~/$HOME}"
    if [[ ! -f "$EXPANDED" && ! -d "$EXPANDED" ]]; then
        MISSING+=("$EXPANDED")
    fi
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    echo "All required files present."
    exit 0
fi

MSG="⏸ BLOCK — required file(s) missing before workspace can run:"
for M in "${MISSING[@]}"; do
    MSG="$MSG\n  • $M"
done
MSG="$MSG\nCreate or restore these files before proceeding."

echo -e "$MSG"
source <(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env 2>/dev/null)
curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$(echo -e "$MSG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()).strip('\"'))")\"}" \
    "https://discord.com/api/v10/channels/$CHANNEL_ID/messages" > /dev/null 2>&1

exit 1
