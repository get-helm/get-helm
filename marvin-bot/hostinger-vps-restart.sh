#!/usr/bin/env bash
# hostinger-vps-restart.sh — Restart VPS VM via Hostinger API when SSH is unreachable.
# Called when vps-service-restart.sh fails (VM fully off, not just services down).
#
# Exit 0 = restart triggered successfully
# Exit 1 = API unreachable or restart failed

set -euo pipefail

VAULT_ITEM="Hostinger API Key"
LOG="${HOME}/marvin-bot/vps-monitor.log"
VPS_IP="{{USER_VPS_IP}}"
API_BASE="https://api.hostinger.com"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [hostinger-restart] $*" >> "$LOG"; }

# Read API key from Vault
API_KEY=$(op item get "$VAULT_ITEM" --vault "PAP Vault" --fields password --reveal 2>/dev/null)
if [[ -z "$API_KEY" ]]; then
  log "ERROR: Could not read API key from Vault — cannot restart VPS"
  exit 1
fi

log "Vault read OK — querying VM list"

# Get VM list and find the VM matching our VPS IP
VM_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Accept: application/json" \
  "${API_BASE}/api/vps/v1/virtual-machines" 2>/dev/null)

HTTP_CODE=$(echo "$VM_RESPONSE" | tail -1)
VM_BODY=$(echo "$VM_RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" != "200" ]]; then
  log "ERROR: VM list returned HTTP $HTTP_CODE — Hostinger API unreachable"
  exit 1
fi

# Extract VM ID matching our VPS IP
VM_ID=$(echo "$VM_BODY" | python3 -c "
import json, sys
data = json.load(sys.stdin)
vms = data.get('data', data) if isinstance(data, dict) else data
if isinstance(vms, list):
    for vm in vms:
        # Check main IP or any IP in network config
        ip = vm.get('main_ip_address') or vm.get('ip_address') or ''
        if '${VPS_IP}' in str(vm) or ip == '${VPS_IP}':
            print(vm.get('id', ''))
            break
" 2>/dev/null)

if [[ -z "$VM_ID" ]]; then
  log "ERROR: Could not find VM with IP ${VPS_IP} in VM list"
  log "VM list response: $(echo "$VM_BODY" | head -c 500)"
  exit 1
fi

log "Found VM ID: $VM_ID — sending restart"

RESTART_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "${API_BASE}/api/vps/v1/virtual-machines/${VM_ID}/restart" 2>/dev/null)

RESTART_CODE=$(echo "$RESTART_RESPONSE" | tail -1)
RESTART_BODY=$(echo "$RESTART_RESPONSE" | head -n -1)

if [[ "$RESTART_CODE" =~ ^2 ]]; then
  log "SUCCESS: VPS restart triggered (HTTP $RESTART_CODE)"
  exit 0
else
  log "ERROR: Restart returned HTTP $RESTART_CODE — body: $(echo "$RESTART_BODY" | head -c 300)"
  exit 1
fi
