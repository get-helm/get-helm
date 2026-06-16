#!/usr/bin/env bash
# second-brain-qmd-update.sh — Nightly re-index of second-brain collection in QMD
# Runs nightly at 3:30 AM PT (after second-brain-discord-ingest.py, before PM sweep)
# Picks up any new files added to ~/helm-workspace/second-brain/ since last run

set -euo pipefail

# Explicit PATH for launchd/cron environments where /opt/homebrew/bin isn't in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/{{USER_HOME}}/.bun/bin:$PATH"

QMD=~/.bun/bin/qmd
LOG=~/marvin-bot/marvin.log

log() {
  # Use >> only (not tee) — plist StandardOutPath already redirects stdout to marvin.log,
  # so tee would cause every line to appear twice.
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [second-brain-qmd-update] $*" >> "$LOG"
}

if [[ ! -x "$QMD" ]]; then
  log "ERROR: qmd not found at $QMD"
  exit 1
fi

# QMD collections are registered relative to ~/helm-workspace (.qmd dir lives there)
cd /Users/{{USER_HOME}}/helm-workspace

# Count files before update
BEFORE=$("$QMD" status 2>/dev/null | grep -A2 "second-brain (qmd" | grep "Files:" | grep -o '[0-9]*' | head -1 || echo "?")

log "Starting update (files before: $BEFORE)"

# Re-index the collection (picks up new/changed files)
"$QMD" update >> "$LOG" 2>&1 || {
  log "WARNING: qmd update returned non-zero (may be normal if no changes)"
}

# Also run embed to add vector embeddings for new files
"$QMD" embed 2>&1 | grep -E '(Embedded|Skipped|Error)' >> "$LOG" || true

AFTER=$("$QMD" status 2>/dev/null | grep -A2 "second-brain (qmd" | grep "Files:" | grep -o '[0-9]*' | head -1 || echo "?")

log "Update complete (files after: $AFTER)"
