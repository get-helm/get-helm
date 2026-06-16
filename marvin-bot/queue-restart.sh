#!/usr/bin/env bash
# queue-restart.sh — Queue a bot restart for the next nightly window (2am PT).
# Agents call this instead of safe-restart.sh after committing bot.js changes.
# {{USER_JERRY}} can force-through at any time by saying "deploy now" in Discord.

set -euo pipefail

PENDING_FLAG=/tmp/pap-pending-restart.flag
LOG=~/marvin-bot/marvin.log
ENV_FILE=~/marvin-bot/.env
PAP_IMPROVEMENTS_CHANNEL={{USER_CHANNEL_HELM_IMPROVEMENTS}}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [queue-restart] $*" | tee -a "$LOG"
}

if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

REASON="${1:-unspecified}"

# Write the flag with metadata
python3 -c "
import json, time, os
flag = '$PENDING_FLAG'
existing = {}
if os.path.exists(flag):
    try:
        existing = json.load(open(flag))
    except Exception:
        existing = {}
commits = existing.get('commits', [])
commits.append({'reason': '$REASON', 'queued_at': int(time.time())})
data = {'pending': True, 'commits': commits, 'updated_at': int(time.time())}
open(flag, 'w').write(json.dumps(data, indent=2))
print('Flag written with', len(commits), 'queued change(s)')
"

QUEUE_DEPTH=$(python3 -c "import json; d=json.load(open('$PENDING_FLAG')); print(len(d.get('commits', [])))")

log "Restart queued: reason='$REASON' (queue depth: $QUEUE_DEPTH)"

# Write to pm-log only — no Discord notification (channel noise reduction)
python3 -c "
import os, time
pm_log = os.path.expanduser('~/helm-workspace/pm-log.md')
entry = f'\n## {time.strftime(\"%Y-%m-%d %H:%M\", time.gmtime())} UTC — restart queued\nReason: $REASON\nQueue depth: $QUEUE_DEPTH\n'
open(pm_log, 'a').write(entry)
" 2>/dev/null || true

log "Done. Restart will fire during next 2am-7am window."
