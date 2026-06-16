#!/bin/bash
# helm-channel-healer.sh
# Ground-truth self-heal for stuck Discord channels.
#
# WHY THIS EXISTS: bot.js's post-exit-watchdog can only re-fire an unanswered
# message when its internal `lastUserContent` field is intact. When that field
# is lost (msgId drift, validation-error phase corruption, staged-deliver strand),
# bot.js goes blind and the channel stays silently stuck. The internal flags
# (lastValidationError, lastAgentMsgPhase) are unreliable — they go stale and
# produce false positives. The ONLY reliable signal is Discord itself: if the
# newest message in a channel is from a human and no agent is running, the user
# is unanswered. This script uses that ground truth, then repopulates the field
# bot.js needs so its proven recovery path re-fires the message.
#
# Invoked every 5 min by helm-healthcheck-ping.sh (only when bot.js is up).
# Logs to helm-audit.log (file only). Silent to user.
# Rollback: remove the healer block at the end of helm-healthcheck-ping.sh + delete this file.

set -uo pipefail
BOT_ID="1498824219633647789"
STATE_DIR="/Users/{{USER_HOME}}/helm-workspace/channel-state"
AUDIT_LOG="/Users/{{USER_HOME}}/helm-workspace/system/helm-audit.log"
STALE_MIN="${STALE_MIN:-8}"        # human msg must be older than this (matches POST_EXIT_RESUME_MS=8m)
MAX_AGE_HRS="${MAX_AGE_HRS:-24}"   # ignore user activity older than this
DRY_RUN="${DRY_RUN:-0}"

TOKEN="${DISCORD_BOT_TOKEN:-$(grep '^DISCORD_BOT_TOKEN=' /Users/{{USER_HOME}}/marvin-bot/.env 2>/dev/null | cut -d= -f2-)}"
if [[ -z "$TOKEN" ]]; then echo "healer: no token" >&2; exit 1; fi

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
healed=0
checked=0

# Stage 1: cheap local pre-filter — channels with NO live agent and recent user activity.
CANDS=$(python3 - "$STATE_DIR" "$MAX_AGE_HRS" <<'PY'
import json, glob, time, os, sys
state_dir, max_hrs = sys.argv[1], float(sys.argv[2])
now = time.time()
for f in glob.glob(os.path.join(state_dir, '*.json')):
    try: d = json.load(open(f))
    except Exception: continue
    pid = d.get('agentPid')
    if pid:
        try:
            os.kill(int(pid), 0)
            continue  # agent alive — not stuck
        except Exception:
            pass
    luma = d.get('lastUserMsgAt') or 0
    if luma > 1e10: luma /= 1000
    if luma > 0 and (now - luma) < max_hrs * 3600:
        print(os.path.basename(f)[:-5])
PY
)

for ch in $CANDS; do
  [[ -z "$ch" ]] && continue
  checked=$((checked+1))
  RESP=$(curl -s --max-time 10 -H "Authorization: Bot ${TOKEN}" \
    "https://discord.com/api/v10/channels/${ch}/messages?limit=1")
  # Stage 2: Discord ground truth — is newest message a human, older than STALE_MIN?
  VERDICT=$(CH="$ch" BOT_ID="$BOT_ID" STALE_MIN="$STALE_MIN" python3 - <<PY
import json, sys, time, datetime, os
resp = """$RESP"""
try:
    arr = json.loads(resp)
except Exception:
    sys.exit()
if not isinstance(arr, list) or not arr:
    sys.exit()
m = arr[0]
author = m.get('author', {})
is_bot = author.get('bot', False)
content = (m.get('content') or '').replace(chr(10), ' ')
try:
    age = (time.time() - datetime.datetime.fromisoformat(m['timestamp']).timestamp()) / 60
except Exception:
    age = -1
stale = float(os.environ['STALE_MIN'])
# Stuck = newest message is a human, older than threshold (agent never replied)
if (not is_bot) and age > stale:
    safe = content.encode('ascii', 'replace').decode()[:120]
    print(f"STUCK|{int(age)}|{m.get('id')}|{safe}")
PY
)
  [[ "$VERDICT" != STUCK* ]] && continue
  IFS='|' read -r _ age msgid content <<< "$VERDICT"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY] would heal $ch (human last, ${age}m old): ${content:0:70}"
    healed=$((healed+1))
    continue
  fi

  # Heal: repopulate the field bot.js's recovery path needs, from Discord ground truth.
  # Set lastUserContent + a non-ack/update phase so orphanedDeliverUnanswered fires next
  # watchdog tick. Clear blocking cruft (validation error, stale checkpoint, dead pid).
  python3 - "$STATE_DIR/$ch.json" "$content" "$msgid" <<'PY'
import json, sys, time
f, content, msgid = sys.argv[1], sys.argv[2], sys.argv[3]
try: d = json.load(open(f))
except Exception: d = {}
d['lastUserContent'] = content
d['lastAgentMsgPhase'] = 'deliver'   # non-ack/update → triggers orphanedDeliverUnanswered
d['agentPid'] = None
d['agentSpawnedAt'] = None
d['lastValidationError'] = None
d['lastProcessedMsgId'] = msgid      # sync so the message isn't treated as already-handled
if d.get('checkpoint'):
    d['checkpoint'] = None           # clear stale checkpoint that blocks retry
json.dump(d, open(f, 'w'), indent=2)
PY
  echo "[$(ts)] [healer] re-armed stuck channel ${ch} (human waited ${age}m) — bot.js watchdog will re-fire" >> "$AUDIT_LOG"
  healed=$((healed+1))
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo "healer DRY-RUN: checked $checked candidates, $healed genuinely stuck"
else
  [[ "$healed" -gt 0 ]] && echo "[$(ts)] [healer] re-armed $healed/$checked candidate channels" >> "$AUDIT_LOG"
fi
exit 0
