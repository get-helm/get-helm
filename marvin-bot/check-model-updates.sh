#!/bin/bash
# check-model-updates.sh — detect new Claude models and post [CONFIRM] to helm-improvements
# Does NOT auto-update. Posts a confirmation prompt; {{USER_JERRY}} approves via button.
# After approval, run: model-auto-update.sh --set [alias] [new-model-id]
# Schedule: daily at 9am PT via pm-jobs.md T1-H or launchd

set -euo pipefail

CONFIG="$HOME/marvin-bot/model-config.json"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LAST_RUN_FILE="$HOME/helm-workspace/system/.model-check-last-run.txt"

log() {
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [check-model-updates] $*" >> "$AUDIT_LOG"
}

# Cooldown: skip if ran within last 20 hours (prevents double-fire from cron overlap)
if [[ -f "$LAST_RUN_FILE" ]]; then
  LAST=$(cat "$LAST_RUN_FILE")
  NOW=$(date -u +%s)
  LAST_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST" +%s 2>/dev/null || echo 0)
  ELAPSED=$(( NOW - LAST_SEC ))
  if [[ $ELAPSED -lt 72000 ]]; then
    log "Cooldown active ($ELAPSED s since last run) — skipping"
    exit 0
  fi
fi

date -u '+%Y-%m-%dT%H:%M:%SZ' > "$LAST_RUN_FILE"

log "Checking for new Claude models..."

# Run model-auto-update.sh in dry-run mode to detect changes without applying
DRY_OUTPUT=$(bash "$HOME/marvin-bot/model-auto-update.sh" --dry-run 2>/dev/null || true)

if echo "$DRY_OUTPUT" | grep -q "\[DRY RUN\] Would apply"; then
  # Changes detected — extract the summary
  CHANGE_SUMMARY=$(echo "$DRY_OUTPUT" | grep "Would apply:" | sed 's/\[DRY RUN\] Would apply://' | tr '\n' ' ')
  log "New models detected: $CHANGE_SUMMARY"

  # Read current config for context
  CURRENT_OPUS=$(python3 -c "import json; print(json.load(open('$CONFIG'))['aliases'].get('opus','?'))" 2>/dev/null || echo '?')
  CURRENT_SONNET=$(python3 -c "import json; print(json.load(open('$CONFIG'))['aliases'].get('sonnet','?'))" 2>/dev/null || echo '?')

  MSG="🔔 **New Claude model detected** — update available:
\`\`\`
$CHANGE_SUMMARY
\`\`\`
Current: opus=$CURRENT_OPUS, sonnet=$CURRENT_SONNET

To apply: run \`bash ~/marvin-bot/model-auto-update.sh\`
To skip: ignore this message (runs again next week via T2-U)

[CONFIRM: Apply model update now|apply_model_update; Skip for now|skip_model_update]"

  "$DISCORD_POST" "$HELM_IMPROVEMENTS" "$MSG"
  log "Posted [CONFIRM] to helm-improvements"
else
  log "No model changes detected — all current"
fi

exit 0
