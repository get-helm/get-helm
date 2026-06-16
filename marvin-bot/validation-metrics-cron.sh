#!/bin/bash
# validation-metrics-cron.sh — runs daily validation and metrics passes
# Called by com.pap.validation-metrics launchd plist (4x daily: 00:15, 06:15, 12:15, 16:15 UTC)

set -euo pipefail

HOME_DIR="$HOME"
AUDIT_LOG="$HOME_DIR/helm-workspace/system/helm-audit.log"

log() {
  local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [validation-metrics-cron] $*" >> "$AUDIT_LOG"
}

log "Starting validation-metrics pass"

# 1. Per-mandate violation trending (alerts if >20% week-over-week spike)
if [[ -f "$HOME_DIR/marvin-bot/mandate-metrics.sh" ]]; then
  bash "$HOME_DIR/marvin-bot/mandate-metrics.sh" || log "mandate-metrics exited non-zero (alerts sent)"
else
  log "mandate-metrics.sh not found — skip"
fi

# 2. Model ID currency check (validates model-config.json alias format)
if [[ -f "$HOME_DIR/marvin-bot/check-model-ids.sh" ]]; then
  bash "$HOME_DIR/marvin-bot/check-model-ids.sh" || log "check-model-ids found drift (alerts sent)"
else
  log "check-model-ids.sh not found — skip"
fi

log "Validation-metrics pass complete"
