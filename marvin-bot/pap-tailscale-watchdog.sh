#!/usr/bin/env bash
# Monitors Tailscale connectivity and attempts auto-recovery.
# Runs every 5 min via com.pap.tailscale.watchdog launchd job.

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
TAILSCALE=/usr/local/bin/tailscale
LOG="$HOME/marvin-bot/tailscale-watchdog.log"
STATUS_CHANNEL='{{USER_CHANNEL_HELM_STATUS}}'  # pap-status

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

post_discord() {
  local token
  token=$(op item get "Marvin Bot Token" --vault "PAP Vault" --fields password --reveal 2>/dev/null)
  [[ -z "$token" ]] && { log "Could not read bot token — skipping Discord alert"; return; }
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bot $token" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"$1\"}" \
    "https://discord.com/api/v10/channels/$STATUS_CHANNEL/messages"
}

check_ts() {
  local out
  out=$($TAILSCALE status 2>&1) || { echo "daemon_down"; return; }
  # Confirm this machine appears with its own Tailscale IP
  echo "$out" | grep -q "{{USER_MAC_TAILSCALE_IP}}" && echo "ok" || echo "disconnected"
}

status=$(check_ts)
log "status=$status"

[[ "$status" == "ok" ]] && exit 0

# --- Recovery attempt 1: tailscale up (handles soft disconnects) ---
log "Tailscale not healthy ($status). Running '$TAILSCALE up --accept-routes'..."
$TAILSCALE up --accept-routes >> "$LOG" 2>&1
sleep 15
status=$(check_ts)
log "After tailscale up: $status"

[[ "$status" == "ok" ]] && { log "Recovered via tailscale up."; exit 0; }

# --- Recovery attempt 2: relaunch the macOS Tailscale app ---
log "Still down. Relaunching Tailscale app..."
pkill -x Tailscale 2>/dev/null || true
sleep 5
open -a Tailscale 2>> "$LOG"
sleep 30
status=$(check_ts)
log "After app relaunch: $status"

[[ "$status" == "ok" ]] && { log "Recovered via app relaunch."; exit 0; }

# --- All recovery attempts failed — alert ---
log "All recovery attempts failed. Alerting."
post_discord "⚠️ **Tailscale is down on Mac Mini** — auto-recovery failed after 2 attempts. SSH via Tailscale ({{USER_MAC_TAILSCALE_IP}}) unavailable. Check Tailscale manually. (Last status: ${status})"
