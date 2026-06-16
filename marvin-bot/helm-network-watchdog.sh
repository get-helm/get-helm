#!/usr/bin/env bash
# helm-network-watchdog.sh — Mac-side network self-heal.
# Runs every 60s via launchd (com.helm.network-watchdog).
# Detects internet loss (the router-reboot incident class) and recovers it
# without human hands: after 3 consecutive failures, power-cycles Wi-Fi.
# Complements pap-tailscale-watchdog.sh, which heals the VPN layer only —
# that one can't help when the underlying Wi-Fi/DNS is dead.

export PATH="/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOG="$HOME/marvin-bot/network-watchdog.log"
FAIL_COUNT_FILE="/tmp/helm-net-fail-count"
CYCLE_COOLDOWN_FILE="/tmp/helm-net-last-cycle"
OUTAGE_START_FILE="/tmp/helm-net-outage-start"
FAIL_THRESHOLD=3        # consecutive failed checks before acting (~3 min)
CYCLE_COOLDOWN=600      # min seconds between Wi-Fi power-cycles

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [net-watchdog] $*" >> "$LOG"; }

wifi_dev() {
  networksetup -listallhardwareports 2>/dev/null \
    | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}'
}

internet_ok() {
  # Raw-IP ping first (works even when DNS is dead), then DNS-dependent check.
  if ping -c 1 -t 5 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -t 5 8.8.8.8 >/dev/null 2>&1; then
    if curl -s -m 8 -o /dev/null https://www.apple.com 2>/dev/null \
       || curl -s -m 8 -o /dev/null https://www.cloudflare.com 2>/dev/null; then
      echo "ok"
    else
      echo "dns-broken"   # IP works, name resolution/TLS doesn't
    fi
  else
    echo "down"
  fi
}

state=$(internet_ok)

HEARTBEAT_FILE="/tmp/helm-net-last-heartbeat"

if [ "$state" = "ok" ]; then
  if [ -f "$OUTAGE_START_FILE" ]; then
    started=$(cat "$OUTAGE_START_FILE" 2>/dev/null || echo 0)
    dur=$(( $(date +%s) - started ))
    log "RECOVERED — internet back after ${dur}s outage"
    rm -f "$OUTAGE_START_FILE"
  fi
  rm -f "$FAIL_COUNT_FILE"
  last_hb=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - last_hb )) -gt 3600 ]; then
    log "heartbeat — internet OK, watchdog alive"
    date +%s > "$HEARTBEAT_FILE"
  fi
  exit 0
fi

# Failure path
[ -f "$OUTAGE_START_FILE" ] || date +%s > "$OUTAGE_START_FILE"
count=$(( $(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$FAIL_COUNT_FILE"
log "Internet check failed (state=$state, consecutive=$count)"

if [ "$count" -lt "$FAIL_THRESHOLD" ]; then
  exit 0
fi

# Threshold reached — attempt Wi-Fi power-cycle (if Wi-Fi is the active path)
last_cycle=$(cat "$CYCLE_COOLDOWN_FILE" 2>/dev/null || echo 0)
if [ $(( $(date +%s) - last_cycle )) -lt "$CYCLE_COOLDOWN" ]; then
  log "Would cycle Wi-Fi but cooldown active — waiting"
  exit 0
fi

DEV=$(wifi_dev)
if [ -z "$DEV" ]; then
  log "No Wi-Fi device found — cannot self-heal"
  exit 0
fi

log "Power-cycling Wi-Fi ($DEV) after $count consecutive failures"
date +%s > "$CYCLE_COOLDOWN_FILE"
networksetup -setairportpower "$DEV" off
sleep 5
networksetup -setairportpower "$DEV" on
sleep 25

state2=$(internet_ok)
if [ "$state2" = "ok" ]; then
  log "Wi-Fi cycle SUCCEEDED — internet restored"
  rm -f "$FAIL_COUNT_FILE" "$OUTAGE_START_FILE"
  # Nudge Tailscale so the VPN path comes back quickly too
  /usr/local/bin/tailscale up --accept-routes >> "$LOG" 2>&1 || true
else
  log "Wi-Fi cycle did not restore internet (state=$state2) — will retry after cooldown"
fi
