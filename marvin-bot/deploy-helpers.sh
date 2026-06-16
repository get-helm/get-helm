#!/bin/bash
# deploy-helpers.sh — shared helpers for workspace deploy phases
# Usage: source ~/marvin-bot/deploy-helpers.sh
# Then call: deploy_with_heartbeat CHANNEL_ID DEPLOY_COMMAND [args...]

# Run a deploy command in background while posting heartbeats every 60s
# Prevents silence-watchdog kills on deploys > 3 min
deploy_with_heartbeat() {
    local CHANNEL_ID="$1"
    shift
    local CMD="$@"

    # Load Discord token
    if [[ -z "$DISCORD_BOT_TOKEN" ]]; then
        source <(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env)
    fi

    _post_heartbeat() {
        local MSG="$1"
        curl -s -X POST \
            -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"⏳ $MSG\"}" \
            "https://discord.com/api/v10/channels/$CHANNEL_ID/messages" > /dev/null 2>&1
    }

    # Run deploy command in background
    local LOG_FILE=$(mktemp /tmp/deploy-heartbeat-XXXXXX.log)
    eval "$CMD" > "$LOG_FILE" 2>&1 &
    local DEPLOY_PID=$!

    local ELAPSED=0
    local INTERVAL=60

    _post_heartbeat "Deploy started — will post updates every ${INTERVAL}s while running..."

    while kill -0 "$DEPLOY_PID" 2>/dev/null; do
        sleep "$INTERVAL"
        ELAPSED=$((ELAPSED + INTERVAL))
        _post_heartbeat "Deploy still running — ${ELAPSED}s elapsed. Waiting for completion..."
    done

    wait "$DEPLOY_PID"
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "Deploy complete (${ELAPSED}s)"
        cat "$LOG_FILE"
        rm -f "$LOG_FILE"
        return 0
    else
        echo "Deploy failed (exit $EXIT_CODE after ${ELAPSED}s):"
        cat "$LOG_FILE"
        rm -f "$LOG_FILE"
        return $EXIT_CODE
    fi
}
