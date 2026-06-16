#!/bin/bash
# helm-log-rotate.sh — Rotate logs exceeding MAX_MB to prevent unbounded growth
# Called from engineer-nightly.sh or as standalone cron (3:30am PT via launchd).
# Rotation: keep last 10MB of each log, truncate older content.

set -euo pipefail

MAX_MB=10
MAX_BYTES=$((MAX_MB * 1024 * 1024))
HELM_AUDIT="$HOME/helm-workspace/system/helm-audit.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ROTATED=0

rotate_if_large() {
  local logfile="$1"
  [[ ! -f "$logfile" ]] && return 0
  local size
  size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)
  if [[ "$size" -gt "$MAX_BYTES" ]]; then
    # Keep last MAX_MB bytes
    tail -c "$MAX_BYTES" "$logfile" > "${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
    echo "[log-rotate] $TIMESTAMP — rotated $(basename $logfile) (was ${size}B → ${MAX_BYTES}B)" >> "$HELM_AUDIT"
    ROTATED=$((ROTATED + 1))
  fi
}

# Bot and system logs
rotate_if_large "$HOME/marvin-bot/marvin.log"
rotate_if_large "$HOME/marvin-bot/heartbeat.log"
rotate_if_large "$HOME/marvin-bot/selfheal-launchd.log"
rotate_if_large "$HOME/marvin-bot/tailscale-watchdog.log"
rotate_if_large "$HOME/marvin-bot/engineer-nightly.log"
rotate_if_large "$HOME/marvin-bot/recovery-poll.log"
rotate_if_large "$HOME/marvin-bot/vps-monitor.log"
rotate_if_large "$HOME/marvin-bot/marvin-discord-heartbeat.log"
rotate_if_large "$HOME/marvin-bot/api-cost-monitor.log"

# Helm workspace logs
rotate_if_large "$HOME/helm-workspace/system/queue-audit.log"
rotate_if_large "$HOME/helm-workspace/system/helm-audit.log"
rotate_if_large "$HOME/helm-workspace/system/friction-log.md"
rotate_if_large "$HOME/helm-workspace/logs/dead-mans-ping.log"
rotate_if_large "$HOME/helm-workspace/logs/drive-drift-check.log"

if [[ "$ROTATED" -gt 0 ]]; then
  echo "[log-rotate] $TIMESTAMP — rotated $ROTATED log(s)" >> "$HELM_AUDIT"
else
  echo "[log-rotate] $TIMESTAMP — all logs under ${MAX_MB}MB, no rotation needed" >> "$HELM_AUDIT"
fi
