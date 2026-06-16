#!/bin/bash
# check-model-ids.sh — validates model IDs in model-config.json match expected Claude patterns
# Catches non-existent model IDs like the /fable→claude-fable-5 incident (2026-06-14)
# Run weekly (T2-U) or after any model-config.json change
# Exit 0: all valid | Exit 1: drift detected (alerts posted)

set -euo pipefail

CONFIG="$HOME/marvin-bot/model-config.json"
OUTPUT="$HOME/helm-workspace/system/model-currency.json"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"

log() {
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [check-model-ids] $*" >> "$AUDIT_LOG"
}

# Python does the real work — avoids bash array quoting complexity
RESULT=$(python3 - "$CONFIG" "$OUTPUT" << 'PYEOF'
import json, sys, re, subprocess
from datetime import datetime, timezone

config_path = sys.argv[1]
output_path = sys.argv[2]

# Valid Claude model ID pattern
# Examples: claude-opus-4-8, claude-sonnet-4-6, claude-haiku-4-5-20251001
VALID = re.compile(r'^claude-(opus|sonnet|haiku)-\d+-\d+(-\d{8})?$')

cfg = json.load(open(config_path))
model_ids = set(cfg.get('aliases', {}).values())
if 'transparency' in cfg and 'fable_fallback_model' in cfg['transparency']:
    model_ids.add(cfg['transparency']['fable_fallback_model'])

valid = []
failed = []
for mid in sorted(model_ids):
    if VALID.match(mid):
        valid.append(mid)
    else:
        failed.append(mid)

ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
result = {
    'checked_at': ts,
    'valid': valid,
    'failed': failed,
    'status': 'ok' if not failed else 'drift_detected'
}
with open(output_path, 'w') as f:
    json.dump(result, f, indent=2)
    f.write('\n')

if failed:
    print(f"DRIFT:{','.join(failed)}")
else:
    print(f"OK:{','.join(valid)}")
PYEOF
)

TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

if [[ "$RESULT" == DRIFT:* ]]; then
  FAILED_IDS="${RESULT#DRIFT:}"
  log "DRIFT DETECTED: $FAILED_IDS — model IDs do not match expected pattern"
  "$DISCORD_POST" "$HELM_IMPROVEMENTS" "⚠️ Model ID drift detected in model-config.json:
**Invalid IDs:** $FAILED_IDS

These do not match the expected Claude model ID format (claude-opus/sonnet/haiku-X-Y).
This is how the /fable→claude-fable-5 silent downgrade happened on 2026-06-14.
Fix: \`bash ~/marvin-bot/model-auto-update.sh --set [alias] [correct-model-id]\`"
  exit 1
else
  VALID_IDS="${RESULT#OK:}"
  log "All model IDs valid: $VALID_IDS"
  exit 0
fi
