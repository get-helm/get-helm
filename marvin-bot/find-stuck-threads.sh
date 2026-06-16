#!/bin/bash
# find-stuck-threads.sh
# Scans channel-state for stuck threads and optionally unsticks them.
#
# Usage:
#   ./find-stuck-threads.sh          — list stuck threads
#   ./find-stuck-threads.sh --fix    — list AND reset all to 'deliver' phase

CHANNEL_STATE_DIR="/Users/{{USER_HOME}}/helm-workspace/channel-state"
FIX_MODE=false
[[ "$1" == "--fix" ]] && FIX_MODE=true

STUCK_COUNT=0
GAVE_UP_COUNT=0
NOW_SEC=$(date +%s)

echo ""
echo "=== Stuck Thread Scanner ==="
echo ""

for f in "$CHANNEL_STATE_DIR"/*.json; do
  [[ -f "$f" ]] || continue
  CHANNEL_ID=$(basename "$f" .json)

  # Parse fields via python3
  PARSED=$(python3 -c "
import json, sys, os
try:
    d = json.load(open('$f'))
    phase = d.get('lastAgentMsgPhase') or ''
    pid = d.get('agentPid')
    attempts = d.get('checkpoint', {}).get('resumeAttempts', 0) or 0
    saved_at = d.get('checkpoint', {}).get('savedAt', 0) or 0
    # Normalize savedAt to seconds
    if saved_at > 1e10:
        saved_at = saved_at / 1000
    age_min = int(($NOW_SEC - saved_at) / 60) if saved_at > 0 else -1
    print(f'{phase}|{pid}|{attempts}|{age_min}')
except Exception as e:
    print(f'error|None|0|-1')
" 2>/dev/null)

  PHASE=$(echo "$PARSED" | cut -d'|' -f1)
  PID=$(echo "$PARSED" | cut -d'|' -f2)
  ATTEMPTS=$(echo "$PARSED" | cut -d'|' -f3)
  AGE=$(echo "$PARSED" | cut -d'|' -f4)

  # Stuck = phase is ack or update, no running agent
  if [[ "$PHASE" == "ack" || "$PHASE" == "update" ]] && [[ "$PID" == "None" || -z "$PID" ]]; then
    STUCK_COUNT=$((STUCK_COUNT + 1))

    if [[ "$ATTEMPTS" -ge 4 ]]; then
      GAVE_UP_COUNT=$((GAVE_UP_COUNT + 1))
      STATUS="⚠️  GAVE UP (4 auto-resume attempts exhausted)"
    else
      STATUS="🔄 auto-resume pending (${ATTEMPTS} attempt(s) so far)"
    fi

    AGE_LABEL="unknown age"
    [[ "$AGE" -ge 0 ]] && AGE_LABEL="${AGE} min old"

    echo "  Thread: $CHANNEL_ID"
    echo "    Phase: $PHASE  |  Age: $AGE_LABEL  |  $STATUS"
    echo ""

    if $FIX_MODE; then
      python3 -c "
import json, time
f = '$f'
d = json.load(open(f))
d['lastAgentMsgPhase'] = 'deliver'
d['agentPid'] = None
d['agentSpawnedAt'] = None
if 'checkpoint' in d and d['checkpoint']:
    d['checkpoint']['resumeAttempts'] = 0
open(f, 'w').write(json.dumps(d, indent=2))
"
      echo "    ✅ Reset to 'deliver' — send any message in this thread to re-engage."
      echo ""
    fi
  fi
done

if [[ "$STUCK_COUNT" -eq 0 ]]; then
  echo "  ✅ No stuck threads found."
else
  echo "  Total stuck: $STUCK_COUNT  (${GAVE_UP_COUNT} gave up, rest still pending auto-resume)"
  if ! $FIX_MODE; then
    echo ""
    echo "  To reset all of these, run: ./find-stuck-threads.sh --fix"
  fi
fi

echo ""
