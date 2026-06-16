#!/usr/bin/env bash
# second-brain-continuous-ingest.sh — Hourly incremental second-brain ingest
# Cron: 0 * * * *
# Runs Discord ingest, SMS ingest stub, and QMD update

# Cron doesn't inherit PATH — set explicitly so node/qmd/bun are found
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/{{USER_HOME}}/.bun/bin:$PATH"

set -euo pipefail

LOG=~/marvin-bot/marvin.log
DISCORD_INGEST=~/marvin-bot/second-brain-discord-ingest-raw.py
EMAIL_INGEST=~/marvin-bot/second-brain-email-ingest-raw.py
SMS_COUNT_FILE=~/helm-workspace/second-brain/.sms-count
QMD_UPDATE=~/marvin-bot/second-brain-qmd-update.sh

AUDIT_LOG=~/helm-workspace/system/helm-audit.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [continuous-ingest] $*" >> "$LOG"
}

alert() {
  log "ALERT: $*"
  # Route to helm-audit.log — PM reviews in T2-C sweep. No Discord noise.
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [continuous-ingest] ALERT: $*" >> "$AUDIT_LOG"
}

log "=== Starting hourly second-brain ingest ==="

# 1. Discord incremental ingest (last 3 days only — full backfill was done on May 23)
log "Running Discord ingest (incremental)..."
if [[ -f "$DISCORD_INGEST" ]]; then
  INCREMENTAL_DAYS=3 /opt/homebrew/bin/python3 "$DISCORD_INGEST" >> "$LOG" 2>&1 || {
    log "Discord ingest: non-zero exit (may be normal)"
  }
else
  alert "Discord ingest script missing from disk — hourly ingest SKIPPED. Check git stash/merge for accidental deletion."
fi

# 2. Email incremental ingest — non-zero exit is a REAL failure (script
# now exits 1 on Gmail fetch errors instead of reporting "0 new emails")
log "Running email ingest (incremental)..."
if [[ -f "$EMAIL_INGEST" ]]; then
  if ! /opt/homebrew/bin/python3 "$EMAIL_INGEST" >> "$LOG" 2>&1; then
    log "Email ingest FAILED (non-zero exit) — see fetch-stderr lines above"
    # Throttle: alert at most once per 6 hours to avoid hourly spam
    STAMP=~/marvin-bot/.email-ingest-alert-stamp
    if [[ ! -f "$STAMP" ]] || [[ $(( $(date +%s) - $(stat -f %m "$STAMP" 2>/dev/null || echo 0) )) -gt 21600 ]]; then
      alert "Email ingest FAILED this hour (Gmail fetch error). Will keep retrying hourly — this alert repeats at most every 6h. Details in marvin.log."
      touch "$STAMP"
    fi
  else
    rm -f ~/marvin-bot/.email-ingest-alert-stamp
  fi
else
  alert "Email ingest script missing from disk — hourly ingest SKIPPED. Check git stash/merge for accidental deletion."
fi

# 3. SMS ingest stub (reads from ~/helm-workspace/second-brain/sms/ if present)
SMS_DIR=~/helm-workspace/second-brain/sms
CURRENT_TOTAL=$(cat "$SMS_COUNT_FILE" 2>/dev/null || echo "0")
log "[sms-ingest] Starting SMS ingest (current total: $CURRENT_TOTAL)"
SMS_FILES=$(find "$SMS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SMS_FILES" -gt "$CURRENT_TOTAL" ]]; then
  echo "$SMS_FILES" > "$SMS_COUNT_FILE"
  log "[sms-ingest] New SMS messages found: $((SMS_FILES - CURRENT_TOTAL))"
  log "[sms-ingest] SMS ingest complete (total: $SMS_FILES)"
else
  log "[sms-ingest] No new SMS messages found"
  log "[sms-ingest] SMS ingest complete (total: $CURRENT_TOTAL)"
fi
# Write SMS health timestamp so watchdog can detect SMS ingest staleness
HEALTH_FILE=~/helm-workspace/second-brain/.ingest-health.json
/opt/homebrew/bin/python3 -c "
import json, sys
from datetime import datetime, timezone
from pathlib import Path
f = Path('$HEALTH_FILE')
try: h = json.loads(f.read_text()) if f.exists() else {}
except Exception: h = {}
h['sms'] = {'last_success': datetime.now(timezone.utc).isoformat()}
f.write_text(json.dumps(h, indent=2))
" 2>/dev/null || true

# 4. Fireflies meeting transcripts (idempotent — only fetches new ones)
log "Running Fireflies transcript pull..."
FIREFLIES_PULL=~/marvin-bot/fireflies-pull.py
if [[ -f "$FIREFLIES_PULL" ]]; then
  /opt/homebrew/bin/python3 "$FIREFLIES_PULL" >> "$LOG" 2>&1 || {
    log "Fireflies pull: non-zero exit (may be no new transcripts or API issue)"
  }
else
  log "Fireflies pull script missing — skipping"
fi

# 5. QMD update (re-index new files)
log "Running QMD update..."
if [[ -f "$QMD_UPDATE" ]]; then
  bash "$QMD_UPDATE" >> "$LOG" 2>&1 || {
    log "QMD update: non-zero exit (may be normal if no changes)"
  }
else
  alert "QMD update script missing from disk — re-index SKIPPED."
fi

# 6. QMD self-test — confirm search works (catches Node/binary mismatch)
# A single `qmd search` round-trip; if it crashes, alert with rebuild command.
log "Running QMD self-test..."
if ! /Users/{{USER_HOME}}/.bun/bin/qmd search "self-test sentinel" >/dev/null 2>&1; then
  alert "QMD search BROKEN — likely native-module / Node mismatch. Run: cd ~/.bun/install/global/node_modules/better-sqlite3 && npm rebuild better-sqlite3"
fi

log "=== Hourly ingest complete ==="
