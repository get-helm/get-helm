#!/usr/bin/env bash
# second-brain-freshness-watchdog.sh
# Runs every 2 hours. Alerts to Discord if:
#   1. Required ingest scripts are missing from disk
#   2. No new second-brain files written in the last 4 hours (during active hours)
# Cron: 0 */2 * * *

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/{{USER_HOME}}/.bun/bin:$PATH"

LOG=~/marvin-bot/marvin.log
SECOND_BRAIN=~/helm-workspace/second-brain
REQUIRED_SCRIPTS=(
  ~/marvin-bot/second-brain-discord-ingest-raw.py
  ~/marvin-bot/second-brain-email-ingest-raw.py
  ~/marvin-bot/second-brain-qmd-update.sh
  ~/marvin-bot/second-brain-continuous-ingest.sh
)

AUDIT_LOG=~/helm-workspace/system/helm-audit.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [freshness-watchdog] $*" >> "$LOG"
}

log_audit() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [freshness-watchdog] $*" >> "$AUDIT_LOG"
}

ALERTS=()

# 1. Check required scripts exist and are non-empty
for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    ALERTS+=("❌ Missing script: $(basename $script)")
    log "ALERT: script missing — $script"
  elif [[ ! -s "$script" ]]; then
    ALERTS+=("❌ Empty script: $(basename $script)")
    log "ALERT: script empty — $script"
  fi
done

# 2. Check freshness — any file in second-brain modified in last 4 hours?
# Skip check between midnight and 6am PT (no ingestion expected)
HOUR_UTC=$(date -u +%H)  # PT = UTC-7, so 6am PT = 13:00 UTC
if (( 10#$HOUR_UTC >= 13 )); then
  RECENT_FILES=$(find "$SECOND_BRAIN" -name "*.md" -newer <(date -v-4H +%Y%m%d%H%M 2>/dev/null || date --date="4 hours ago" +%Y%m%d%H%M 2>/dev/null || echo "") 2>/dev/null | wc -l | tr -d ' ')
  # macOS compatible: check mtime within 4 hours
  RECENT_FILES=$(find "$SECOND_BRAIN" -name "*.md" -mmin -240 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$RECENT_FILES" -eq 0 ]]; then
    ALERTS+=("⚠️ No new second-brain files in last 4 hours — ingest may be stalled")
    log "ALERT: no recent files in second-brain (last 4 hours)"
  else
    log "Freshness OK — $RECENT_FILES files modified in last 4 hours"
  fi
fi

# 2b. Per-source health check — each ingest writes .ingest-health.json on SUCCESS.
# This catches the failure mode where files exist but a specific source is dark
# (e.g. email failing hourly while Discord keeps writing — June 5-12 gap).
HEALTH_FILE="$SECOND_BRAIN/.ingest-health.json"
if [[ -f "$HEALTH_FILE" ]]; then
  for source in discord email; do
    AGE_H=$(/opt/homebrew/bin/python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    h = json.load(open('$HEALTH_FILE'))
    ts = h.get('$source', {}).get('last_success')
    if not ts:
        print(999); sys.exit()
    dt = datetime.fromisoformat(ts)
    print(round((datetime.now(timezone.utc) - dt).total_seconds() / 3600, 1))
except Exception:
    print(999)
" 2>/dev/null || echo 999)
    if (( $(echo "$AGE_H > 3" | bc -l) )); then
      ALERTS+=("⚠️ ${source} ingest: no successful run in ${AGE_H}h (hourly expected)")
      log "ALERT: $source ingest stale — last success ${AGE_H}h ago"
    else
      log "$source ingest healthy — last success ${AGE_H}h ago"
    fi
  done
  # Fireflies and SMS: alert at 25h (run hourly but low-volume sources)
  for source in fireflies sms; do
    AGE_H=$(/opt/homebrew/bin/python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    h = json.load(open('$HEALTH_FILE'))
    ts = h.get('$source', {}).get('last_success')
    if not ts:
        print(999); sys.exit()
    dt = datetime.fromisoformat(ts)
    print(round((datetime.now(timezone.utc) - dt).total_seconds() / 3600, 1))
except Exception:
    print(999)
" 2>/dev/null || echo 999)
    if (( $(echo "$AGE_H > 25" | bc -l) )); then
      ALERTS+=("⚠️ ${source} ingest: no successful run in ${AGE_H}h (>25h threshold)")
      log "ALERT: $source ingest stale — last success ${AGE_H}h ago"
    else
      log "$source ingest healthy — last success ${AGE_H}h ago"
    fi
  done
else
  ALERTS+=("⚠️ ingest health file missing — no ingest has reported success since deploy")
  log "ALERT: .ingest-health.json missing"
fi

# 3. Write alert to helm-audit.log for PM T2-C review (no Discord noise)
if [[ ${#ALERTS[@]} -gt 0 ]]; then
  for alert in "${ALERTS[@]}"; do
    log_audit "ALERT: $alert"
  done
  log_audit "Second brain watchdog: ${#ALERTS[@]} issue(s) — PM reviews in T2-C sweep"
  log "Alert written to helm-audit.log: ${#ALERTS[@]} issue(s) — no Discord post"
else
  log "All checks passed — no alerts"
fi
