#!/bin/bash
# model-auto-update.sh — checks for new Claude model versions and updates model-config.json
# Usage:
#   ./model-auto-update.sh              — auto-detect from `claude models list`
#   ./model-auto-update.sh --set opus claude-opus-4-8   — manual override for an alias
#   ./model-auto-update.sh --dry-run    — print changes without applying

set -euo pipefail

CONFIG="$HOME/marvin-bot/model-config.json"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DRY_RUN=false
MANUAL_ALIAS=""
MANUAL_MODEL_ID=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --set)
      MANUAL_ALIAS="$2"
      MANUAL_MODEL_ID="$3"
      shift 3
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

log() {
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [model-auto-update] $*" >> "$AUDIT_LOG"
  echo "$*"
}

# Manual override mode
if [[ -n "$MANUAL_ALIAS" ]]; then
  log "Manual override: setting $MANUAL_ALIAS → $MANUAL_MODEL_ID"
  if $DRY_RUN; then
    echo "[DRY RUN] Would set aliases.$MANUAL_ALIAS = $MANUAL_MODEL_ID"
    exit 0
  fi
  python3 - <<EOF
import json
p = '$CONFIG'
with open(p) as f:
    cfg = json.load(f)

old = cfg['aliases'].get('$MANUAL_ALIAS', 'unset')
cfg['aliases']['$MANUAL_ALIAS'] = '$MANUAL_MODEL_ID'

# Also update transparency fallback if applicable
if '$MANUAL_ALIAS' in ('opus', 'fable'):
    cfg['transparency']['fable_fallback_model'] = '$MANUAL_MODEL_ID'

with open(p, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')

print(f"Updated aliases.$MANUAL_ALIAS: {old} → $MANUAL_MODEL_ID")
EOF
  exit 0
fi

# Auto-detect mode: parse `claude models list`
log "Running auto-detect from claude models list..."

CLI_MODELS=$(claude models list 2>/dev/null || echo "")

if [[ -z "$CLI_MODELS" ]]; then
  log "ERROR: claude models list returned empty output"
  exit 1
fi

# Extract model IDs from the table (lines like: | Opus 4.7 | `claude-opus-4-7` |)
CLI_OPUS=$(echo "$CLI_MODELS" | grep -i "opus" | grep -oE 'claude-opus-[0-9.-]+' | head -1 || true)
CLI_SONNET=$(echo "$CLI_MODELS" | grep -i "sonnet" | grep -oE 'claude-sonnet-[0-9.-]+' | head -1 || true)
CLI_HAIKU=$(echo "$CLI_MODELS" | grep -i "haiku" | grep -oE 'claude-haiku-[0-9.-]+[0-9]*' | head -1 || true)

log "CLI reports: opus=${CLI_OPUS:-none} sonnet=${CLI_SONNET:-none} haiku=${CLI_HAIKU:-none}"

# Read current config
CURRENT_OPUS=$(python3 -c "import json; print(json.load(open('$CONFIG'))['aliases']['opus'])")
CURRENT_SONNET=$(python3 -c "import json; print(json.load(open('$CONFIG'))['aliases']['sonnet'])")
CURRENT_HAIKU=$(python3 -c "import json; print(json.load(open('$CONFIG'))['aliases']['haiku'])")

log "Config has: opus=$CURRENT_OPUS sonnet=$CURRENT_SONNET haiku=$CURRENT_HAIKU"

CHANGES=""
UPDATE_OPUS=""
UPDATE_SONNET=""
UPDATE_HAIKU=""

# Extract numeric version from model ID for comparison (e.g. "claude-opus-4-8" → "4.8")
model_version() {
  echo "$1" | grep -oE '[0-9]+[-\.][0-9]+' | tail -1 | tr '-' '.'
}

# Returns 0 if $1 > $2 (first version is newer), 1 otherwise
is_newer() {
  python3 -c "
import sys
a = list(map(int, '$1'.split('.')))
b = list(map(int, '$2'.split('.')))
sys.exit(0 if a > b else 1)
" 2>/dev/null
}

# Compare versions — only update if CLI shows a NEWER model (never downgrade)
if [[ -n "$CLI_OPUS" && "$CLI_OPUS" != "$CURRENT_OPUS" ]]; then
  CLI_VER=$(model_version "$CLI_OPUS")
  CUR_VER=$(model_version "$CURRENT_OPUS")
  if is_newer "$CLI_VER" "$CUR_VER"; then
    UPDATE_OPUS="$CLI_OPUS"
    CHANGES="$CHANGES\n  opus: $CURRENT_OPUS → $CLI_OPUS (CLI is newer)"
  else
    log "Skipping opus: config ($CURRENT_OPUS) is same or newer than CLI ($CLI_OPUS)"
  fi
fi

if [[ -n "$CLI_SONNET" && "$CLI_SONNET" != "$CURRENT_SONNET" ]]; then
  CLI_VER=$(model_version "$CLI_SONNET")
  CUR_VER=$(model_version "$CURRENT_SONNET")
  if is_newer "$CLI_VER" "$CUR_VER"; then
    UPDATE_SONNET="$CLI_SONNET"
    CHANGES="$CHANGES\n  sonnet: $CURRENT_SONNET → $CLI_SONNET (CLI is newer)"
  else
    log "Skipping sonnet: config ($CURRENT_SONNET) is same or newer than CLI ($CLI_SONNET)"
  fi
fi

if [[ -n "$CLI_HAIKU" && "$CLI_HAIKU" != "$CURRENT_HAIKU" ]]; then
  CLI_VER=$(model_version "$CLI_HAIKU")
  CUR_VER=$(model_version "$CURRENT_HAIKU")
  if is_newer "$CLI_VER" "$CUR_VER"; then
    UPDATE_HAIKU="$CLI_HAIKU"
    CHANGES="$CHANGES\n  haiku: $CURRENT_HAIKU → $CLI_HAIKU (CLI is newer)"
  else
    log "Skipping haiku: config ($CURRENT_HAIKU) is same or newer than CLI ($CLI_HAIKU)"
  fi
fi

if [[ -z "$CHANGES" ]]; then
  log "No changes needed — all models current."
  exit 0
fi

log "Changes detected:$(echo -e "$CHANGES")"

if $DRY_RUN; then
  echo "[DRY RUN] Would apply:$(echo -e "$CHANGES")"
  exit 0
fi

# Apply updates
python3 - <<EOF
import json

p = '$CONFIG'
with open(p) as f:
    cfg = json.load(f)

changes = []

if '$UPDATE_OPUS':
    old = cfg['aliases']['opus']
    cfg['aliases']['opus'] = '$UPDATE_OPUS'
    cfg['aliases']['fable'] = '$UPDATE_OPUS'
    cfg['transparency']['fable_fallback_model'] = '$UPDATE_OPUS'
    changes.append(f"opus/fable: {old} → $UPDATE_OPUS")

if '$UPDATE_SONNET':
    old = cfg['aliases']['sonnet']
    cfg['aliases']['sonnet'] = '$UPDATE_SONNET'
    changes.append(f"sonnet: {old} → $UPDATE_SONNET")

if '$UPDATE_HAIKU':
    old = cfg['aliases']['haiku']
    cfg['aliases']['haiku'] = '$UPDATE_HAIKU'
    changes.append(f"haiku: {old} → $UPDATE_HAIKU")

with open(p, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')

print("Applied: " + ", ".join(changes))
EOF

# Notify via Discord (L1 action — system-visible change)
CHANGE_SUMMARY=$(echo -e "$CHANGES" | sed 's/^  //')
"$DISCORD_POST" "$HELM_IMPROVEMENTS" "⏳ Model config auto-updated — newer models detected in Claude CLI:
$CHANGE_SUMMARY

No restart needed — bot reads config fresh on each request."

log "Config updated and Discord notified."
