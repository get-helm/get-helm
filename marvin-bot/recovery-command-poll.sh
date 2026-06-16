#!/usr/bin/env bash
# recovery-command-poll.sh
# Runs on the clean machine every 60 seconds via launchd.
# Polls the VPS recovery API for queued commands and executes them.
# Called by: ~/Library/LaunchAgents/com.helm.recovery-poll.plist

set -euo pipefail

BASE_URL="https://mission-control.{{USER_DOMAIN}}"
TOKEN_FILE="$HOME/helm-workspace/recovery-api-token"
LOG="$HOME/marvin-bot/recovery-poll.log"
MARVIN_DIR="$HOME/marvin-bot"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [recovery-poll] $*" >> "$LOG"
}

# Token for authenticating with VPS recovery API
if [[ ! -f "$TOKEN_FILE" ]]; then
    log "No token file at $TOKEN_FILE — skipping poll"
    exit 0
fi
TOKEN=$(cat "$TOKEN_FILE")

# Poll for pending command
RESPONSE=$(curl -s -m 10 \
    -H "X-Recovery-Token: $TOKEN" \
    "${BASE_URL}/api/pending-command" \
    -w "\n%{http_code}" 2>/dev/null || echo "curl-error")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

if [[ "$HTTP_CODE" == "204" ]] || [[ "$HTTP_CODE" == "" ]]; then
    exit 0  # no pending command
fi

if [[ "$HTTP_CODE" != "200" ]]; then
    log "Unexpected status $HTTP_CODE from VPS — skipping"
    exit 0
fi

ACTION=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('action',''))" <<< "$BODY" 2>/dev/null || echo "")
if [[ -z "$ACTION" ]]; then
    log "Empty action in response — skipping"
    exit 0
fi

log "Received command: $ACTION"
RESULT="done"

case "$ACTION" in
    restart)
        log "Executing restart"
        # V3 fix: check for in-flight agents with fresh checkpoints before --force.
        # An in-flight agent gets 60s to reach a checkpoint before we kill it.
        IN_FLIGHT_PID=$(python3 -c "
import json, glob, os, time
for f in glob.glob(os.path.expanduser('~/helm-workspace/channel-state/*.json')):
    try:
        d = json.load(open(f))
        pid = d.get('agentPid')
        phase = d.get('lastAgentMsgPhase', '')
        saved = d.get('checkpoint', {}).get('savedAt', 0) if d.get('checkpoint') else 0
        if pid and phase in ('ack','update') and saved:
            saved_ms = saved * 1000 if saved < 1e10 else saved
            age_s = (time.time() * 1000 - saved_ms) / 1000
            if age_s < 120:  # checkpoint < 2min old = agent actively working
                try: os.kill(int(pid), 0); print(pid); break
                except: pass
    except: pass
" 2>/dev/null || echo "")
        if [[ -n "$IN_FLIGHT_PID" ]]; then
            log "In-flight agent PID=$IN_FLIGHT_PID with fresh checkpoint — waiting 60s grace before restart"
            sleep 60
            log "Grace period elapsed — proceeding with restart"
        fi
        if bash "$MARVIN_DIR/safe-restart.sh" --force >> "$LOG" 2>&1; then
            RESULT="ok"
            log "Restart complete"
        else
            RESULT="restart-failed"
            log "Restart failed"
        fi
        ;;
    rollback)
        log "Executing rollback to last known-good commit"
        # Find last commit before today
        PREV_COMMIT=$(git -C "$MARVIN_DIR" log --before=yesterday --format="%H" -1 2>/dev/null || true)
        if [[ -z "$PREV_COMMIT" ]]; then
            RESULT="no-rollback-target"
            log "No previous commit found for rollback"
        else
            git -C "$MARVIN_DIR" checkout "$PREV_COMMIT" -- bot.js >> "$LOG" 2>&1 || true
            if bash "$MARVIN_DIR/safe-restart.sh" --force >> "$LOG" 2>&1; then
                RESULT="ok"
                log "Rollback + restart complete (commit: $PREV_COMMIT)"
            else
                RESULT="rollback-restart-failed"
                log "Rollback done but restart failed"
            fi
        fi
        ;;
    test)
        log "Executing connection test"
        RESULT="ok"
        ;;
    *)
        log "Unknown action: $ACTION"
        RESULT="unknown-action"
        ;;
esac

# Clear command and post result
curl -s -m 10 \
    -X POST \
    -H "X-Recovery-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"$ACTION\",\"result\":\"$RESULT\"}" \
    "${BASE_URL}/api/clear-command" >> "$LOG" 2>&1 || true

log "Command $ACTION completed with result: $RESULT"
