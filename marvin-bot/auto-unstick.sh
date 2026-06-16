#!/bin/bash
# auto-unstick.sh
# Runs every 15 min via cron. Finds truly stuck threads (gave up auto-resume
# or stuck > 10 min with no agent PID), fixes them, and notifies #pap-improvements.
# Also detects frozen agents: live PID + age >20min + CPU <1% (FROZEN-AGENT-DETECT-001)

CHANNEL_STATE_DIR="/Users/{{USER_HOME}}/helm-workspace/channel-state"
NOTIFY_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"  # helm-status — only for gave-up alerts
NOW_SEC=$(date +%s)
FIXED=()
GAVE_UP=()
FROZEN=()

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

  # --- Frozen-agent detection: live PID + old + idle CPU ---
  if [[ "$PHASE" == "ack" || "$PHASE" == "update" ]] && \
     [[ "$PID" != "None" && -n "$PID" ]] && \
     [[ "$AGE" -ge 20 ]]; then
    # Check if PID is alive
    if kill -0 "$PID" 2>/dev/null; then
      # Get CPU usage (macOS: ps -p PID -o %cpu=). Sample twice, 3s apart, so a
      # healthy agent that is momentarily idle (e.g. waiting on a Claude API call)
      # can't be killed by one unlucky reading — only a SUSTAINED ~0% counts as frozen.
      CPU=$(ps -p "$PID" -o %cpu= 2>/dev/null | tr -d ' ')
      IS_IDLE=$(awk "BEGIN { print (\"$CPU\" + 0 < 1.0) ? \"yes\" : \"no\" }" 2>/dev/null)
      if [[ "$IS_IDLE" == "yes" ]]; then
        sleep 3
        CPU=$(ps -p "$PID" -o %cpu= 2>/dev/null | tr -d ' ')
        IS_IDLE=$(awk "BEGIN { print (\"$CPU\" + 0 < 1.0) ? \"yes\" : \"no\" }" 2>/dev/null)
      fi
      if [[ "$IS_IDLE" == "yes" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        sleep 1
        kill -9 "$PID" 2>/dev/null
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
        FROZEN+=("$CHANNEL_ID (PID=$PID, age=${AGE}m, CPU=${CPU}% — killed+cleared)")
        continue
      fi
    fi
  fi

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

TOTAL=$(( ${#FIXED[@]} + ${#GAVE_UP[@]} + ${#FROZEN[@]} ))

if [[ ${#GAVE_UP[@]} -gt 0 ]]; then
  ~/marvin-bot/pm-log-write.sh "auto-unstick" "GAVE_UP: ${GAVE_UP[*]} — needs manual re-send. PM: surface to user if still stuck at next sweep."
fi
if [[ ${#FROZEN[@]} -gt 0 ]]; then
  ~/marvin-bot/pm-log-write.sh "auto-unstick" "FROZEN-AGENT killed: ${FROZEN[*]} — PID alive but idle >20min, force-cleared."
fi
# All auto-unstick events → pm-log only. PM escalates if action needed.
