#!/bin/bash
# auto-unstick.sh
# Runs every 15 min via cron. Finds truly stuck threads (gave up auto-resume
# or stuck > 10 min with no agent PID), fixes them, and notifies #pap-improvements.

CHANNEL_STATE_DIR="/Users/{{USER_HOME}}/helm-workspace/channel-state"
NOTIFY_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"  # helm-status — only for gave-up alerts
NOW_SEC=$(date +%s)
FIXED=()
GAVE_UP=()

for f in "$CHANNEL_STATE_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  CHANNEL_ID=$(basename "$f" .json)

  PARSED=$(python3 -c "
import json, sys
try:
    d = json.load(open('$f'))
    phase = d.get('lastAgentMsgPhase') or ''
    pid = d.get('agentPid')
    attempts = d.get('checkpoint', {}).get('resumeAttempts', 0) or 0
    saved_at = d.get('checkpoint', {}).get('savedAt', 0) or 0
    if saved_at > 1e10:
        saved_at = saved_at / 1000
    age_min = int(($NOW_SEC - saved_at) / 60) if saved_at > 0 else -1
    print(f'{phase}|{pid}|{attempts}|{age_min}')
except:
    print('|None|0|-1')
" 2>/dev/null)

  PHASE=$(echo "$PARSED" | cut -d'|' -f1)
  PID=$(echo "$PARSED" | cut -d'|' -f2)
  ATTEMPTS=$(echo "$PARSED" | cut -d'|' -f3)
  AGE=$(echo "$PARSED" | cut -d'|' -f4)

  # Only act if stuck (ack/update with no agent PID)
  [[ "$PHASE" == "ack" || "$PHASE" == "update" ]] || continue
  [[ "$PID" == "None" || -z "$PID" ]] || continue

  # Fix if: gave up (4+ attempts) OR stuck > 20 min
  if [[ "$ATTEMPTS" -ge 4 ]] || [[ "$AGE" -ge 20 ]]; then
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
"
    if [[ "$ATTEMPTS" -ge 4 ]]; then
      GAVE_UP+=("$CHANNEL_ID (gave up after 4 attempts, age ${AGE}m)")
    else
      FIXED+=("$CHANNEL_ID (stuck ${AGE}m, no agent running)")
    fi
  fi
done

TOTAL=$(( ${#FIXED[@]} + ${#GAVE_UP[@]} ))

if [[ ${#GAVE_UP[@]} -gt 0 ]]; then
  ~/marvin-bot/pm-log-write.sh "auto-unstick" "GAVE_UP: ${GAVE_UP[*]} — needs manual re-send. PM: surface to user if still stuck at next sweep."
fi
# All auto-unstick events → pm-log only. PM escalates if action needed.
