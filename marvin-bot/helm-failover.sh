#!/usr/bin/env bash
# helm-failover.sh — fast dead-man failover trigger (TASK-069)
# Runs every 30s via launchd com.pap.failover. Detects heartbeat silence >60s.
# Faster than helm-selfheal.sh (5min → 60s threshold).

HEARTBEAT_FILE=/tmp/marvin-heartbeat
LOG=~/marvin-bot/marvin.log
AUDIT_LOG=~/helm-workspace/pap-audit.log
STATUS_CHANNEL={{USER_CHANNEL_HELM_STATUS}}
COOLDOWN_FILE=/tmp/helm-restart-cooldown-global  # shared with selfheal — one restart per 120s system-wide (V1 fix)
COOLDOWN_SECS=120  # 2 min shared cooldown across all restart watchdogs
MAX_STALE_MS=60000 # 60s heartbeat silence = frozen

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [failover] $*" | tee -a "$LOG"
}

# Skip if bot.js not running — launchd handles that case, not us
BOT_PID=$(pgrep -f "node bot.js" | head -1 || true)
if [[ -z "$BOT_PID" ]]; then
  log "bot.js not running — skipping (launchd will restart)"
  exit 0
fi

# Read heartbeat timestamp
if [[ ! -f "$HEARTBEAT_FILE" ]]; then
  log "No heartbeat file found — skipping"
  exit 0
fi

LAST_HB=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo "0")
NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
STALE_MS=$((NOW_MS - LAST_HB))

if [[ $STALE_MS -lt $MAX_STALE_MS ]]; then
  # Healthy — quiet exit
  exit 0
fi

STALE_SECS=$((STALE_MS / 1000))
log "STALE heartbeat: ${STALE_SECS}s (threshold=60s). bot.js PID=$BOT_PID appears frozen."

# Cooldown gate
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_TRIGGER=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
  NOW_SECS=$(date +%s)
  ELAPSED=$((NOW_SECS - LAST_TRIGGER))
  if [[ $ELAPSED -lt $COOLDOWN_SECS ]]; then
    log "Cooldown active — ${ELAPSED}s since last trigger. Skipping."
    exit 0
  fi
fi

date +%s > "$COOLDOWN_FILE"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [failover] TRIGGER stale=${STALE_SECS}s pid=$BOT_PID" >> "$AUDIT_LOG"

# Alert Discord
ENV_FILE=~/marvin-bot/.env
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"⚡ Failover triggered — heartbeat silent ${STALE_SECS}s (threshold 60s). Auto-restarting.\"}" \
    "https://discord.com/api/v10/channels/$STATUS_CHANNEL/messages" || true
fi

log "Triggering safe-restart.sh --skip-guard"
/bin/bash ~/marvin-bot/safe-restart.sh --skip-guard || {
  log "safe-restart.sh failed — killing for launchd recovery"
  kill "$BOT_PID" 2>/dev/null || true
}
