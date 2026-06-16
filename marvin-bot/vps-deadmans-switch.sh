#!/usr/bin/env bash
# vps-deadmans-switch.sh — VPS-side watchdog for HELM.
# Deploy to VPS at: /root/vps-deadmans-switch.sh
# Cron: */5 * * * * /bin/bash /root/vps-deadmans-switch.sh >> /root/vps-deadmans.log 2>&1
#
# How it works:
# 1. Checks when VPS last received a heartbeat from Mac Mini (/opt/pap-health/last-heartbeat.txt)
# 2. If >15 min stale AND Mac Mini appears UP (Tailscale reachable), SSHes in and restarts bot.js
# 3. If still stale after 60s, posts Discord alert
#
# Discord alerts are ONLY posted for failures:
# - SSH restart failed (manual action needed)
# - Still stale after restart (manual action needed)
# Successful auto-restarts are logged locally only.
#
# Requirements:
# - VPS has SSH key in Mac Mini authorized_keys (root@srv1426953 already authorized)
# - Mac Mini Tailscale IP: {{USER_MAC_TAILSCALE_IP}}
# - Discord bot token in /root/.env (DISCORD_BOT_TOKEN=...)

set -euo pipefail

MAC_MINI_IP="{{USER_MAC_TAILSCALE_IP}}"
MAC_MINI_USER="${HELM_MAC_USER:-$(whoami)}"
HEARTBEAT_FILE="/opt/pap-health/last-heartbeat.txt"
MAX_STALE_SECS=900
COOLDOWN_FILE="/tmp/vps-deadmans-last-trigger"
COOLDOWN_SECS=600
STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
LOG="/root/vps-deadmans.log"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vps-deadmans] $*"
}

# Load Discord token
if [[ -f /root/.env ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' /root/.env | head -1) 2>/dev/null || true
fi

# Check heartbeat file
if [[ ! -f "$HEARTBEAT_FILE" ]]; then
  log "No heartbeat file at $HEARTBEAT_FILE — cannot assess staleness"
  exit 0
fi

LAST_HB_TS=$(cat "$HEARTBEAT_FILE" 2>/dev/null | tr -d '[:space:]' || echo "0")
NOW_TS=$(date +%s)

# Heartbeat file stores Unix timestamp (seconds)
if ! [[ "$LAST_HB_TS" =~ ^[0-9]+$ ]]; then
  log "Invalid heartbeat timestamp: $LAST_HB_TS"
  exit 0
fi

STALE_SECS=$((NOW_TS - LAST_HB_TS))

if [[ $STALE_SECS -lt $MAX_STALE_SECS ]]; then
  log "Heartbeat OK — ${STALE_SECS}s ago"
  exit 0
fi

log "STALE heartbeat: ${STALE_SECS}s (threshold=${MAX_STALE_SECS}s)"

# Cooldown check
if [[ -f "$COOLDOWN_FILE" ]]; then
  LAST_TRIGGER=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
  ELAPSED=$((NOW_TS - LAST_TRIGGER))
  if [[ $ELAPSED -lt $COOLDOWN_SECS ]]; then
    log "Cooldown active — ${ELAPSED}s since last trigger. Skipping."
    exit 0
  fi
fi

# Verify Mac Mini is reachable via Tailscale (avoid false positives when Tailscale is down)
if ! ping -c 1 -W 3 "$MAC_MINI_IP" >/dev/null 2>&1; then
  log "Mac Mini at $MAC_MINI_IP not reachable via Tailscale — skipping restart (may be Tailscale outage)"
  exit 0
fi

log "Mac Mini is UP. Triggering SSH restart."
date +%s > "$COOLDOWN_FILE"

# SSH into Mac Mini and restart bot.js
SSH_RESULT=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=yes \
  "$MAC_MINI_USER@$MAC_MINI_IP" \
  "/bin/bash ~/marvin-bot/safe-restart.sh --skip-guard" 2>&1 || echo "SSH_FAILED")

post_discord_alert() {
  local msg="$1"
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    curl -s -o /dev/null -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$msg\"}" \
      "https://discord.com/api/v10/channels/$STATUS_CHANNEL/messages" || true
  fi
}

if echo "$SSH_RESULT" | grep -q "SSH_FAILED"; then
  MSG="⚠️ VPS dead-man's switch: bot.js heartbeat ${STALE_SECS}s stale. SSH restart attempt FAILED. Manual intervention needed."
  log "$MSG"
  post_discord_alert "$MSG"
else
  log "SSH restart sent. Waiting 60s to verify recovery."
  sleep 60

  # Check heartbeat again
  NEW_HB=$(cat "$HEARTBEAT_FILE" 2>/dev/null | tr -d '[:space:]' || echo "0")
  NEW_NOW=$(date +%s)
  NEW_STALE=$((NEW_NOW - NEW_HB))

  if [[ $NEW_STALE -lt $MAX_STALE_SECS ]]; then
    log "Recovery confirmed — heartbeat now ${NEW_STALE}s ago (auto-restarted, no Discord alert)"
    # Success: log only, no Discord noise
  else
    MSG="⚠️ VPS dead-man's switch: restarted bot.js but still stale after 60s (${NEW_STALE}s). Check Mac Mini."
    log "$MSG"
    post_discord_alert "$MSG"
  fi
fi
