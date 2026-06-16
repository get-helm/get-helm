#!/usr/bin/env bash
# vps-service-restart.sh — Mac Mini SSHes into VPS and restarts HELM services.
# Called by vps-monitor-check.sh when HC.io reports VPS DOWN but SSH may still work
# (VM up, services crashed). Does NOT help if VPS VM is fully off.
#
# Exit 0 = restart succeeded (services now running)
# Exit 1 = SSH failed or services still down after restart attempt

set -euo pipefail

VPS_HOST="{{USER_VPS_IP}}"
VPS_USER="root"
LOG="$HOME/marvin-bot/vps-monitor.log"
SERVICES=("helm-recovery.service" "pap-heartbeat.service" "pap-internal-auth.service")

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vps-restart] $*" >> "$LOG"; }

log "Attempting VPS service restart via SSH"

# Test SSH connectivity first (5s timeout)
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
    "${VPS_USER}@${VPS_HOST}" "echo ok" > /dev/null 2>&1; then
  log "SSH unreachable — VPS VM is likely fully down, not just service crash"
  exit 1
fi

log "SSH reachable — restarting HELM services"

# Restart all HELM services and collect results
FAILED=()
for SVC in "${SERVICES[@]}"; do
  if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes \
      "${VPS_USER}@${VPS_HOST}" "systemctl restart ${SVC} && systemctl is-active ${SVC}" > /dev/null 2>&1; then
    log "${SVC}: restarted OK"
  else
    log "${SVC}: restart FAILED"
    FAILED+=("$SVC")
  fi
done

if [[ ${#FAILED[@]} -eq 0 ]]; then
  log "All VPS services restarted successfully"
  exit 0
else
  log "Failed services: ${FAILED[*]}"
  exit 1
fi
