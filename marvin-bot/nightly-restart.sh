#!/usr/bin/env bash
# nightly-restart.sh — Scheduled nightly bot restart
# Fires every 15 min via launchd. Only acts during 10 PM–5:59 AM window.
# Uses a done-tonight flag so it only restarts once per night (window-date-based, not calendar-date).
# If not complete by 6 AM, pings {{USER_JERRY}} for intervention.

set -euo pipefail

MORATORIUM_FLAG=~/helm-workspace/restart-moratorium.flag
CHANNEL_STATE_DIR=~/helm-workspace/channel-state
LOG=~/marvin-bot/marvin.log
PAP_STATUS_CHANNEL={{USER_CHANNEL_HELM_STATUS}}
ENV_FILE=~/marvin-bot/.env
PENDING_RESTART_FLAG=/tmp/pap-pending-restart.flag

# Compute current hour and window date FIRST (window crosses midnight: 10PM–6AM)
# Window date = the calendar date when the 10 PM window opened.
# At midnight the date ticks forward, but we're still in the same overnight window.
CURRENT_HOUR=$((10#$(date +%H)))
if [[ "$CURRENT_HOUR" -ge 22 ]]; then
  WINDOW_DATE=$(date +%Y%m%d)
else
  WINDOW_DATE=$(date -v-1d +%Y%m%d)
fi
DONE_FLAG=/tmp/pap-nightly-restart-done-${WINDOW_DATE}
FLAGGED_FILE=/tmp/pap-nightly-restart-flagged-${WINDOW_DATE}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [nightly-restart] $*" | tee -a "$LOG"
}

if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

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

# Check for any in-flight agents. Prints blocking PID or empty string.
check_in_flight() {
  for STATE_FILE in "$CHANNEL_STATE_DIR"/*.json; do
    [[ -f "$STATE_FILE" ]] || continue
    AGENT_PID=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('agentPid') or '')" 2>/dev/null || true)
    LAST_PHASE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('lastAgentMsgPhase') or '')" 2>/dev/null || true)
    [[ -z "$AGENT_PID" ]] && continue
    if ps -p "$AGENT_PID" > /dev/null 2>&1 && [[ "$LAST_PHASE" != "deliver" ]] && [[ "$LAST_PHASE" != "block" ]]; then
      echo "$AGENT_PID"
      return
    fi
  done
}

# Multi-restart mode: allow repeated restarts overnight if /tmp/pap-multi-restart-mode exists.
# Use case: engineer runs with Level 4 changes that each need a restart + validation.
MULTI_RESTART_MODE=false
[[ -f "/tmp/pap-multi-restart-mode" ]] && MULTI_RESTART_MODE=true

# Normal mode: already completed tonight — exit silently.
if [[ "$MULTI_RESTART_MODE" != "true" ]] && [[ -f "$DONE_FLAG" ]]; then
  exit 0
fi

# Multi-restart mode: only restart when there's a pending commit to deploy.
if [[ "$MULTI_RESTART_MODE" == "true" ]] && [[ ! -f "$PENDING_RESTART_FLAG" ]]; then
  exit 0
fi

# Outside the 10 PM–5:59 AM window (only act between 10 PM and 6 AM).
if [[ "$CURRENT_HOUR" -ge 6 ]] && [[ "$CURRENT_HOUR" -lt 22 ]]; then
  # Past 6 AM and still no done flag — flag for user intervention once.
  if [[ "$CURRENT_HOUR" -ge 6 ]] && [[ ! -f "$FLAGGED_FILE" ]]; then
    touch "$FLAGGED_FILE"
    log "Past 6 AM without completing nightly restart — flagging for user intervention"
    bash ~/marvin-bot/pm-log-write.sh "nightly-restart" "MISSED_WINDOW: Agents were in-flight all night, restart did not run. Pending changes still staged. PM: surface to user at next sweep."
    # Nightly restart miss → pm-log only. PM surfaces if pending changes need deploy.
  fi
  # Outside window and no pending flag — nothing to do.
  [[ ! -f "$PENDING_RESTART_FLAG" ]] && exit 0
  # If it's past 7 AM but there's a pending flag, still defer — nightly window only.
  exit 0
fi

log "Nightly restart check starting (hour=$CURRENT_HOUR)"

# Check if there's a reason to restart tonight (either scheduled nightly or pending queue).
HAVE_PENDING=false
[[ -f "$PENDING_RESTART_FLAG" ]] && HAVE_PENDING=true

# Log what's queued if pending flag is set
if [[ "$HAVE_PENDING" == "true" ]]; then
  QUEUE_INFO=$(python3 -c "import json; d=json.load(open('$PENDING_RESTART_FLAG')); print(len(d.get('commits',[])), 'queued change(s)')" 2>/dev/null || echo "unknown changes")
  log "Pending restart flag found: $QUEUE_INFO"
fi

# Pre-check: any in-flight agents?
BLOCKING_PID=$(check_in_flight)
if [[ -n "$BLOCKING_PID" ]]; then
  log "In-flight agent PID=$BLOCKING_PID — deferring. Will retry at next 15-min interval."
  exit 0
fi

log "No in-flight agents — proceeding"
log "Nightly restart starting at $(date +%H:%M) PT — silent (no Discord post)"

# Lift moratorium so safe-restart.sh can proceed.
rm -f "$MORATORIUM_FLAG"
log "Moratorium lifted"

# Re-check AFTER moratorium lift to close the race window between check and lift.
# If an agent spawned in that gap, abort and restore the moratorium.
BLOCKING_PID=$(check_in_flight)
if [[ -n "$BLOCKING_PID" ]]; then
  log "Agent PID=$BLOCKING_PID started between moratorium lift and restart — aborting, restoring moratorium"
  touch "$MORATORIUM_FLAG"
  exit 0
fi

# Mark done before restarting so launchd re-fires (every 15 min) don't double-restart.
# In multi-restart mode, skip the done flag so subsequent pending commits can restart too.
if [[ "$MULTI_RESTART_MODE" != "true" ]]; then
  touch "$DONE_FLAG"
  log "Marked done for tonight — executing restart"
else
  log "Multi-restart mode active — executing restart (will check again at next 15-min interval)"
fi

# Layer 3: Auto-revert mechanism — validate changes before committing to restart
log "Running auto-revert validation"
if ! /bin/bash ~/marvin-bot/auto-revert.sh; then
  log "Auto-revert failed — aborting restart"
  exit 1
fi
log "Auto-revert validation passed — proceeding with restart"

# Apply staged instruction-file changes (TOKEN-CACHE-WINDOW-001)
# Agents stage changes in system/instruction-staging/ (with # APPLY_TO: header) instead of
# editing always-injected files mid-day, protecting the 94.4% prompt cache hit rate.
STAGING_DIR=~/helm-workspace/system/instruction-staging
for STAGED_FILE in "$STAGING_DIR"/*.md "$STAGING_DIR"/*.txt "$STAGING_DIR"/*.sh; do
  [[ -f "$STAGED_FILE" ]] || continue
  BASENAME=$(basename "$STAGED_FILE")
  [[ "$BASENAME" == "README.md" ]] && continue
  DEST=$(head -1 "$STAGED_FILE" | grep '^# APPLY_TO:' | sed 's/^# APPLY_TO: *//' || true)
  if [[ -z "$DEST" ]]; then
    log "[instruction-staging] WARNING: no # APPLY_TO: header in $BASENAME — skipping"
    continue
  fi
  if [[ -f "$DEST" ]]; then
    cp "$STAGED_FILE" "$DEST"
    log "[instruction-staging] Applied $BASENAME → $DEST"
    rm -f "$STAGED_FILE"
  else
    log "[instruction-staging] WARNING: target $DEST does not exist — skipping $BASENAME"
  fi
done

# U2 fix: capture restart exit code. If it fails, remove the done flag so tonight's
# window can retry at the next 15-min launchd fire rather than waiting 24h.
if ! SKIP_AUTO_REVERT=true /bin/bash ~/marvin-bot/safe-restart.sh --force; then
  log "safe-restart.sh FAILED — removing done flag so nightly window can retry"
  rm -f "$DONE_FLAG"
  exit 1
fi
log "safe-restart.sh returned successfully"

# Clear the pending restart flag — changes are now deployed.
if [[ -f "$PENDING_RESTART_FLAG" ]]; then
  rm -f "$PENDING_RESTART_FLAG"
  log "Cleared pending restart flag"
fi

# Verify bot came back up — wait up to 30s for the process to appear
BOT_UP=false
for i in 1 2 3; do
  sleep 10
  if pgrep -f "node.*bot.js" > /dev/null 2>&1; then
    BOT_UP=true
    break
  fi
  log "Bot not detected after attempt $i — waiting..."
done

if [[ "$BOT_UP" == "true" ]]; then
  # Notify VPS watchdog that restart completed successfully
  curl -s -o /dev/null -m 5 -X POST "http://{{USER_VPS_TAILSCALE_IP}}:9876/restart" || true
  log "Notified VPS watchdog of successful restart"

  # Layer 4: Agent resumption — detect stalled agents and trigger resumption
  log "Running agent resumption scanning"
  /bin/bash ~/marvin-bot/agent-resumption.sh || log "Warning: agent resumption failed"
fi

if [[ "$BOT_UP" == "false" ]]; then
  log "ERROR: Bot did not restart after nightly restart — sending email fallback"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  BODY="PAP nightly restart failed at ${TS}. Bot.js did not come back online after 3 attempts (30s each).

Suggested steps:
  1. SSH to Mac Mini and run: launchctl start com.pap.marvin
  2. Or run: cd ~/marvin-bot && node bot.js &
  3. Check ~/marvin-bot/marvin.log for errors

This is an automated fallback notification from nightly-restart.sh."
  /bin/bash ~/marvin-bot/pap-notify-ntfy.sh "PAP Restart Failed" "$BODY" || \
    log "ntfy fallback also failed — {{USER_JERRY}} has no notification. Check marvin.log."
fi
