#!/usr/bin/env bash
# helm-selfheal.sh — Mac Mini self-watchdog.
# Runs every 30s via launchd. Two checks:
#   1. Heartbeat staleness: if bot.js hasn't written heartbeat in 60s → frozen process
#   2. Event-stream silence: if no Discord events for 45 min → bot alive but not processing
# Uses --skip-guard so the one-change gate doesn't block emergency recovery.

set -euo pipefail

HEARTBEAT_FILE=/tmp/marvin-heartbeat
LOG=~/marvin-bot/marvin.log
AUDIT_LOG=~/helm-workspace/pap-audit.log
STATUS_CHANNEL={{USER_CHANNEL_HELM_STATUS}}  # #helm-status
COOLDOWN_FILE=/tmp/helm-restart-cooldown-global  # shared with failover — one restart per 120s system-wide
COOLDOWN_SECS=120  # 120s shared cooldown across all restart watchdogs (V1 fix)
MAX_STALE_SECS=60   # 60s heartbeat silence = frozen (TASK-069)
EVENT_STREAM="$HOME/helm-workspace/event-stream.jsonl"
EVENT_STALE_THRESH=2700  # 45 min — dead-man switch

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [selfheal] $*" | tee -a "$LOG"
}

# Skip if bot.js is not running at all — launchd handles that case
BOT_PID=$(pgrep -f "node bot.js" | head -1 || true)
if [[ -z "$BOT_PID" ]]; then
  log "bot.js not running — skipping selfheal (launchd will restart)"
  exit 0
fi

# Check heartbeat staleness
if [[ ! -f "$HEARTBEAT_FILE" ]]; then
  log "No heartbeat file — cannot assess staleness, skipping"
  exit 0
fi

LAST_HB=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo "0")
NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
# Heartbeat file stores epoch ms
STALE_MS=$((NOW_MS - LAST_HB))
STALE_SECS=$((STALE_MS / 1000))

RESTART_REASON=""

# Check 1: heartbeat staleness
if [[ $STALE_SECS -ge $MAX_STALE_SECS ]]; then
  RESTART_REASON="heartbeat stale ${STALE_SECS}s (threshold=${MAX_STALE_SECS}s)"
  log "STALE heartbeat: ${STALE_SECS}s. bot.js PID=$BOT_PID appears frozen."
fi

# Check 2: event-stream silence (dead-man switch — only if heartbeat is OK)
if [[ -z "$RESTART_REASON" ]] && [[ -f "$EVENT_STREAM" ]]; then
  LAST_EVENT_TS=$(tail -1 "$EVENT_STREAM" | python3 -c "import sys,json; d=json.loads(sys.stdin.read().strip()); print(d.get('ts',''))" 2>/dev/null || echo "")
  if [[ -n "$LAST_EVENT_TS" ]]; then
    LAST_EVENT_EPOCH=$(python3 -c "from datetime import datetime; print(int(datetime.fromisoformat('${LAST_EVENT_TS}'.replace('Z','+00:00')).timestamp()))" 2>/dev/null || echo "0")
    NOW_SECS_ES=$(date +%s)
    EVENT_STALE_SECS=$((NOW_SECS_ES - LAST_EVENT_EPOCH))
    if [[ $EVENT_STALE_SECS -gt $EVENT_STALE_THRESH ]]; then
      RESTART_REASON="Dead-man switch triggered: silence >${EVENT_STALE_THRESH}s (${EVENT_STALE_SECS}s since last event)"
      log "Dead-man switch triggered: silence ${EVENT_STALE_SECS}s (threshold=${EVENT_STALE_THRESH}s) — bot alive but not processing events"
    else
      log "Heartbeat OK — ${STALE_SECS}s ago. Event-stream active — last event ${EVENT_STALE_SECS}s ago."
    fi
  else
    log "Heartbeat OK — ${STALE_SECS}s ago. (Event-stream: no ts field on last line)"
  fi
fi

# All checks passed
if [[ -z "$RESTART_REASON" ]]; then
  exit 0
fi

# Cooldown — don't trigger repeatedly
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_TRIGGER=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
  NOW_SECS=$(date +%s)
  ELAPSED=$((NOW_SECS - LAST_TRIGGER))
  if [[ $ELAPSED -lt $COOLDOWN_SECS ]]; then
    log "Cooldown active — ${ELAPSED}s since last selfheal trigger. Skipping."
    exit 0
  fi
fi

date +%s > "$COOLDOWN_FILE"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [selfheal] TRIGGER reason=\"${RESTART_REASON}\" pid=$BOT_PID" >> "$AUDIT_LOG"

# Post Discord alert before restart
ENV_FILE=~/marvin-bot/.env
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

  # Self-healed event → write to audit log, not status channel (per channel-consolidation directive)
  printf '[%s] [selfheal] ⚡ Self-heal triggered — %s. Auto-restarting now.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${RESTART_REASON}" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true

# STATUS-HEALTH-DOT-001: rename #helm-status to 🔴 before restart (shows bot is down)
if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
  curl -s -o /dev/null -X PATCH \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"🔴helm-status"}' \
    "https://discord.com/api/v10/channels/$STATUS_CHANNEL" || true
  log "Renamed #helm-status → 🔴helm-status (bot going down)"
fi

# Send ntfy push so {{USER_JERRY}}'s phone gets alerted even if Discord bot is silent
~/marvin-bot/pap-notify-ntfy.sh "⚡ HELM self-healing" "Bot frozen — ${RESTART_REASON}. Auto-restarting now." 2>/dev/null || true

log "Triggering safe-restart.sh --skip-guard (reason: ${RESTART_REASON})"
if /bin/bash ~/marvin-bot/safe-restart.sh --skip-guard; then
  log "safe-restart.sh succeeded"
else
  log "safe-restart.sh failed — trying direct kill for launchd recovery"
  kill "$BOT_PID" 2>/dev/null || true
  # Emergency alert: write to helm-audit + post to Discord
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [selfheal] EMERGENCY restart failed for PID $BOT_PID — ${RESTART_REASON}" >> "$AUDIT_LOG"
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    curl -s -o /dev/null -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"⛔ EMERGENCY: selfheal restart FAILED for bot.js (PID $BOT_PID). Reason: ${RESTART_REASON}. Manual intervention required.\"}" \
      "https://discord.com/api/v10/channels/$STATUS_CHANNEL/messages" || true
  fi
fi
