#!/usr/bin/env bash
# helm-back-online.sh — fires when bot.js starts up.
# If the bot was offline for >5 min, sends "HELM is back online" to Discord (#helm-status).
# Called from bot.js startup (or safe-restart.sh).

set -euo pipefail

LOG="$HOME/marvin-bot/helm-back-online.log"
DISCORD_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"  # #helm-status
DISCORD_SCRIPT="$HOME/marvin-bot/discord-post.sh"
LAST_DOWN_FILE="$HOME/marvin-bot/.last-down-timestamp"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"; }

# Check if the heartbeat was missed for more than 5 minutes before startup.
# Heartbeat posts every 5 min — if last heartbeat was >10 min ago, we were offline.
VPS_STATUS=$(curl -s -m 5 "http://{{USER_VPS_TAILSCALE_IP}}:9876/status" 2>/dev/null || echo '{}')
LAST_HB=$(echo "$VPS_STATUS" | python3 -c "import json,sys; print(json.load(sys.stdin).get('heartbeat','never'))" 2>/dev/null || echo "never")

if [[ "$LAST_HB" == "never" ]]; then
  # Can't determine — skip notification
  log "VPS unreachable — skipping back-online check"
  exit 0
fi

# Convert last heartbeat to epoch using Python (handles microseconds in ISO 8601)
LAST_HB_EPOCH=$(python3 -c "
import sys
from datetime import datetime, timezone
ts = sys.argv[1]
try:
    # Handle both with and without fractional seconds, with Z suffix
    ts = ts.rstrip('Z').split('.')[0]  # strip microseconds and Z
    dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception as e:
    print(0)
" "$LAST_HB" 2>/dev/null || echo "0")
NOW_EPOCH=$(date +%s)
GAP=$(( NOW_EPOCH - LAST_HB_EPOCH ))

# Guard: if epoch parse failed (epoch=0 or negative gap), gap is meaningless — skip
if [[ "$LAST_HB_EPOCH" == "0" ]] || [[ $GAP -lt 0 ]]; then
  log "Date parse failed for heartbeat '$LAST_HB' — skipping back-online check"
  exit 0
fi

# Were we down? If last heartbeat is recent, bot was not offline.
if [[ $GAP -lt 360 ]]; then
  # Last heartbeat within 6 min — routine restart, no user notification
  log "Routine restart — last heartbeat ${GAP}s ago, no notification sent"
  rm -f "$LAST_DOWN_FILE"
  exit 0
fi

# We were offline for >6 min — notify
DOWN_DURATION_MIN=$(( GAP / 60 ))
log "Back online after ~${DOWN_DURATION_MIN} min offline — sending notifications"

# Self-healed recovery → audit log, not status channel (per channel-consolidation directive)
printf '[%s] [back-online] ✅ HELM back online — was offline ~%d min. Self-healed.\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${DOWN_DURATION_MIN}" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || \
  log "helm-audit.log write failed"

# Clear the down timestamp marker
rm -f "$LAST_DOWN_FILE"
log "Back-online logged to helm-audit.log (not posted to Discord)"
