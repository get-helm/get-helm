#!/usr/bin/env bash
# agent-resumption.sh — Detect stalled agents after restart and trigger resumption
# Called by nightly-restart.sh after bot comes back online
# Scans channel-state/*.json for agents with savedAt > 2× cadence, spawns pm-agent-trigger

set -euo pipefail

CHANNEL_STATE_DIR=~/helm-workspace/channel-state
PAP_IMPROVEMENTS_CHANNEL={{USER_CHANNEL_HELM_IMPROVEMENTS}}
ENV_FILE=~/marvin-bot/.env
LOG=~/marvin-bot/marvin.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [agent-resumption] $*" | tee -a "$LOG"
}

post_discord() {
  local channel="$1"
  local msg="$2"
  [[ -z "${DISCORD_BOT_TOKEN:-}" ]] && return
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$msg\"}" \
    "https://discord.com/api/v10/channels/$channel/messages" || true
}

# Load Discord token
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

log "Agent resumption scanning — detecting stalled agents"

RESUMED_COUNT=0
NOW_TS=$(date +%s)

# V2 fix: collect ALL stalled channels before writing triggers.
# Old code wrote one file per channel, overwriting — only the last channel was resumed.
# New code: per-channel trigger files so ALL stalled channels get resumption triggers.
declare -a STALLED_CHANNELS
declare -A STALLED_ELAPSED

for STATE_FILE in "$CHANNEL_STATE_DIR"/*.json; do
  [[ -f "$STATE_FILE" ]] || continue

  CHANNEL_ID=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('channelId',''))" 2>/dev/null || echo "")
  AGENT_PID=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('agentPid') or '')" 2>/dev/null || echo "")
  LAST_AGENT_MSG_TS=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('lastAgentMsgTs') or 0)" 2>/dev/null || echo "0")
  LAST_PHASE=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('lastAgentMsgPhase') or '')" 2>/dev/null || echo "")

  # Skip if no agent was running
  [[ -z "$AGENT_PID" ]] && continue
  [[ -z "$CHANNEL_ID" ]] && continue

  # Skip if phase is terminal (already finished)
  if [[ "$LAST_PHASE" == "deliver" ]] || [[ "$LAST_PHASE" == "block" ]]; then
    log "Channel $CHANNEL_ID: phase is $LAST_PHASE — skip (already finished)"
    continue
  fi

  # Calculate time since last message
  ELAPSED_SEC=$((NOW_TS - LAST_AGENT_MSG_TS))

  # If it's been less than 30 seconds since last message, agent is likely still working
  if [[ $ELAPSED_SEC -lt 30 ]]; then
    log "Channel $CHANNEL_ID: recent activity (${ELAPSED_SEC}s ago) — skip"
    continue
  fi

  log "Channel $CHANNEL_ID: stalled (no UPDATE for ${ELAPSED_SEC}s, phase=$LAST_PHASE) — queued for resumption"
  STALLED_CHANNELS+=("$CHANNEL_ID")
  STALLED_ELAPSED["$CHANNEL_ID"]="$ELAPSED_SEC"
done

# Write one trigger file per stalled channel (not one file for all — avoids overwrite)
for CHANNEL_ID in "${STALLED_CHANNELS[@]:-}"; do
  [[ -z "$CHANNEL_ID" ]] && continue
  ELAPSED_SEC="${STALLED_ELAPSED[$CHANNEL_ID]:-0}"
  TRIGGER_FILE=~/helm-workspace/pm-agent-trigger-${CHANNEL_ID}.json
  python3 << PYTHON_END
import json
trigger = {
    "channel_id": "$CHANNEL_ID",
    "message": "Resuming work after system restart. Reading messages and evaluating work completed.",
    "reason": "auto-resumption: stalled for ${ELAPSED_SEC}s"
}
with open("${TRIGGER_FILE}", "w") as f:
    json.dump(trigger, f, indent=2)
PYTHON_END
  log "Wrote per-channel trigger for $CHANNEL_ID"
  RESUMED_COUNT=$((RESUMED_COUNT + 1))
done

if [[ $RESUMED_COUNT -gt 0 ]]; then
  log "Agent resumption: triggered $RESUMED_COUNT stalled agent(s)"
  # L3 act-then-notify → audit log (not helm-improvements; per channel-consolidation directive)
  printf '[%s] [agent-resumption] ✨ System restarted. %d agent(s) resuming.\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RESUMED_COUNT" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true
else
  log "Agent resumption: no stalled agents found"
fi

exit 0
