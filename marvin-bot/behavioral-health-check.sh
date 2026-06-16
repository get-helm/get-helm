#!/bin/bash
# behavioral-health-check.sh — daily behavioral smoke test for claude agent execution
# Runs Check 4 from safe-restart.sh independently so multi-day uptimes stay monitored.
# Alerts #helm-status on failure. Alerts #helm-improvements if claude binary missing.
# Schedule: daily 9am PT (17:00 UTC) via launchd com.helm.behavioral-health

set -euo pipefail

LOG="$HOME/marvin-bot/logs/marvin.log"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
ENV_FILE="$HOME/marvin-bot/.env"
HELM_STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LAST_RUN_FILE="$HOME/helm-workspace/system/.behavioral-health-last-run.txt"

log() {
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [behavioral-health] $*" | tee -a "$AUDIT_LOG"
}

# Cooldown: skip if ran within last 20 hours
if [[ -f "$LAST_RUN_FILE" ]]; then
  LAST=$(cat "$LAST_RUN_FILE")
  NOW=$(date -u +%s)
  LAST_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST" +%s 2>/dev/null || echo 0)
  ELAPSED=$(( NOW - LAST_SEC ))
  if [[ $ELAPSED -lt 72000 ]]; then
    log "Cooldown active ($ELAPSED s since last run) — skipping"
    exit 0
  fi
fi

date -u '+%Y-%m-%dT%H:%M:%SZ' > "$LAST_RUN_FILE"

# Load bot token for alerts
DISCORD_BOT_TOKEN=""
[[ -f "$ENV_FILE" ]] && export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1) || true

discord_alert() {
  local channel="$1"
  local msg="$2"
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    curl -s -o /dev/null -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$msg")}" \
      "https://discord.com/api/v10/channels/$channel/messages" || true
  fi
}

CLAUDE_BIN="/Users/{{USER_HOME}}/.local/bin/claude"

if [[ ! -x "$CLAUDE_BIN" ]]; then
  log "SKIP: claude binary not found at $CLAUDE_BIN"
  discord_alert "$HELM_IMPROVEMENTS" "⚠️ Daily behavioral health check SKIPPED — claude binary not found at \`$CLAUDE_BIN\`. Agent execution is unverified."
  exit 0
fi

log "Starting behavioral tool-call test..."

SMOKE_TMPFILE="/tmp/behavioral-health-$(date +%s)"
echo "behavioral-health-marker" > "$SMOKE_TMPFILE"

AGENT_OUT=$(timeout 60 "$CLAUDE_BIN" --dangerously-skip-permissions -p \
  "Read the file at $SMOKE_TMPFILE and reply with only the word: TOOLCALL_VERIFIED" 2>&1 \
  || echo "AGENT_FAILED_OR_TIMEOUT")

rm -f "$SMOKE_TMPFILE"

if echo "$AGENT_OUT" | grep -q "TOOLCALL_VERIFIED"; then
  log "Behavioral tool-call PASS"
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] behavioral-health: PASS" >> "$HOME/helm-workspace/system/helm-audit.log"
else
  SNIPPET=$(echo "$AGENT_OUT" | head -1 | cut -c1-120)
  log "Behavioral tool-call FAIL — output: $(echo "$AGENT_OUT" | head -3)"
  discord_alert "$HELM_STATUS_CHANNEL" "⚠️ Daily behavioral health check FAILED: claude agent tool-call did not return TOOLCALL_VERIFIED. Output: ${SNIPPET}. Diagnose with: cat ~/marvin-bot/logs/marvin.log | tail -50"
  exit 1
fi

exit 0
