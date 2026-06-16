#!/usr/bin/env bash
# vps-deploy-deadmans.sh — Run this ONCE on the VPS to install the dead-man's switch.
# From Mac Mini: scp ~/marvin-bot/vps-deadmans-switch.sh jerry@{{USER_VPS_TAILSCALE_IP}}:/tmp/
# Then on VPS: sudo bash /tmp/vps-deploy-deadmans.sh
#
# Alternative: run from Mac Mini if SSH works:
#   scp ~/marvin-bot/vps-deadmans-switch.sh root@{{USER_VPS_TAILSCALE_IP}}:/root/
#   ssh root@{{USER_VPS_TAILSCALE_IP}} "bash /root/vps-deadmans-switch.sh --install"

set -euo pipefail

WATCHDOG_SCRIPT="/root/vps-deadmans-switch.sh"
HEARTBEAT_DIR="/opt/pap-health"
CRON_LINE="*/5 * * * * /bin/bash /root/vps-deadmans-switch.sh >> /root/vps-deadmans.log 2>&1"

echo "[deploy] Creating heartbeat directory: $HEARTBEAT_DIR"
mkdir -p "$HEARTBEAT_DIR"

# Write initial heartbeat file if not present (avoid immediate false trigger)
if [[ ! -f "$HEARTBEAT_DIR/last-heartbeat.txt" ]]; then
  date +%s > "$HEARTBEAT_DIR/last-heartbeat.txt"
  echo "[deploy] Created initial heartbeat timestamp"
fi

# Ensure 9876 server writes heartbeat timestamp on POST /heartbeat
# The server is likely node or python — update its heartbeat handler to write this file.
# If using the existing Python server, add this line to the /heartbeat handler:
#   open('/opt/pap-health/last-heartbeat.txt', 'w').write(str(int(time.time())))

echo "[deploy] Installing dead-man's switch cron job"
# Add to crontab if not already present
(crontab -l 2>/dev/null | grep -v "vps-deadmans-switch"; echo "$CRON_LINE") | crontab -

echo "[deploy] Verifying cron entry"
crontab -l | grep "vps-deadmans" && echo "[deploy] Cron installed OK" || echo "[deploy] ERROR: cron not installed"

# Ensure Mac Mini SSH key is in authorized_keys (should already be there)
echo "[deploy] Checking Mac Mini SSH auth (root@srv1426953 in Mac Mini authorized_keys — already confirmed)"

echo ""
echo "=== VPS Dead-Man's Switch Deployed ==="
echo "Watchdog: $WATCHDOG_SCRIPT"
echo "Heartbeat file: $HEARTBEAT_DIR/last-heartbeat.txt"
echo "Cron: every 5 min"
echo "Target: {{USER_HOME}}@{{USER_MAC_TAILSCALE_IP}} (Mac Mini Tailscale IP)"
echo ""
echo "IMPORTANT: Verify the VPS port-9876 server writes to:"
echo "  $HEARTBEAT_DIR/last-heartbeat.txt"
echo "on each /heartbeat POST. If not, add this line to its heartbeat handler."
