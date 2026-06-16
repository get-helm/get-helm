#!/bin/bash
# stuck-channel-monitor-temp.sh
# Runs in background for 3 hours, checks every 5 min for stuck channels.
EXPIRY_EPOCH=1781646323  # 2026-06-16T21:45:23Z (3h from script creation)
CHANNEL_STATE_DIR="/Users/{{USER_HOME}}/helm-workspace/channel-state"
DISCORD_CHANNEL="1510783493477498993"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"

while [[ "$(date +%s)" -lt "$EXPIRY_EPOCH" ]]; do
  NOW=$(date +%s)
  FIXED=()

  for f in "$CHANNEL_STATE_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    CHANNEL_ID=$(basename "$f" .json)
    PARSED=$(python3 -c "
import json, time
try:
    d = json.load(open('$f'))
    phase = d.get('lastAgentMsgPhase') or ''
    pid = d.get('agentPid')
    saved = d.get('checkpoint', {}).get('savedAt', 0) or 0
    if saved > 1e10: saved = saved / 1000
    age_min = int((time.time() - saved) / 60) if saved > 0 else -1
    print(f'{phase}|{pid}|{age_min}')
except:
    print('|None|-1')
" 2>/dev/null)
    PHASE=$(echo "$PARSED" | cut -d'|' -f1)
    PID=$(echo "$PARSED" | cut -d'|' -f2)
    AGE=$(echo "$PARSED" | cut -d'|' -f3)

    [[ "$PHASE" == "ack" || "$PHASE" == "update" ]] || continue
    [[ "$PID" == "None" || -z "$PID" ]] || continue
    [[ "$AGE" -ge 5 ]] || continue

    python3 -c "
import json
f = '$f'
d = json.load(open(f))
d['lastAgentMsgPhase'] = 'deliver'
d['agentPid'] = None
d['agentSpawnedAt'] = None
if 'checkpoint' in d and d['checkpoint']:
    d['checkpoint']['resumeAttempts'] = 0
open(f, 'w').write(json.dumps(d, indent=2))
" 2>/dev/null
    FIXED+=("<#$CHANNEL_ID> (${AGE}m)")
  done

  if [[ ${#FIXED[@]} -gt 0 ]]; then
    "$DISCORD_POST" "$DISCORD_CHANNEL" "🔧 Cleared ${#FIXED[@]} stuck channel(s): ${FIXED[*]}"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Fixed: ${FIXED[*]}"
  fi

  sleep 300
done

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Monitor expired — shutting down"
