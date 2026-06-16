#!/usr/bin/env bash
# pre-restart-validate.sh — Validate critical files before bot.js restart.
# Called automatically by safe-restart.sh before killing the running process.
# Exit 0 = all checks passed (safe to deploy).
# Exit 1 = a check failed; auto-reverted to last known-good commit + notified {{USER_JERRY}}.

set -euo pipefail

MARVIN_DIR="$HOME/marvin-bot"
WORKDIR="$HOME/helm-workspace"
LAST_GOOD_FILE="$WORKDIR/channel-state/last-good-deploy.txt"
PAP_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LOG="$MARVIN_DIR/marvin.log"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [pre-restart-validate] $*" | tee -a "$LOG"
}

post_discord() {
  "$MARVIN_DIR/discord-post.sh" "$1" "$2" 2>/dev/null || true
}

CURRENT_HEAD=$(git -C "$MARVIN_DIR" rev-parse HEAD 2>/dev/null || echo "")
LAST_GOOD=""
if [ -f "$LAST_GOOD_FILE" ]; then
  LAST_GOOD=$(cat "$LAST_GOOD_FILE" | tr -d '[:space:]')
fi

# First run: establish baseline from current HEAD
if [ -z "$LAST_GOOD" ] && [ -n "$CURRENT_HEAD" ]; then
  echo "$CURRENT_HEAD" > "$LAST_GOOD_FILE"
  LAST_GOOD="$CURRENT_HEAD"
fi

FAIL_REASON=""
FAIL_FILE=""

# 1. bot.js syntax (node --check)
if ! /opt/homebrew/bin/node --check "$MARVIN_DIR/bot.js" 2>/tmp/pap-validate-err; then
  FAIL_FILE="bot.js"
  FAIL_REASON="node --check: $(head -2 /tmp/pap-validate-err 2>/dev/null | tr '\n' ' ')"
fi

# 2. Critical shell scripts syntax (bash -n) — discord-post test + safe-restart + health scripts
if [ -z "$FAIL_REASON" ]; then
  for f in \
    "$MARVIN_DIR/discord-post.sh" \
    "$MARVIN_DIR/safe-restart.sh" \
    "$MARVIN_DIR/pap-health-check.sh" \
    "$MARVIN_DIR/pm-heartbeat.sh"; do
    [ -f "$f" ] || continue
    if ! bash -n "$f" 2>/tmp/pap-validate-err; then
      FAIL_FILE="$(basename "$f")"
      FAIL_REASON="bash -n: $(head -2 /tmp/pap-validate-err 2>/dev/null | tr '\n' ' ')"
      break
    fi
  done
fi

# 3. Python files syntax (python -m py_compile)
if [ -z "$FAIL_REASON" ]; then
  for f in "$MARVIN_DIR"/*.py; do
    [ -f "$f" ] || continue
    if ! python3 -m py_compile "$f" 2>/tmp/pap-validate-err; then
      FAIL_FILE="$(basename "$f")"
      FAIL_REASON="py_compile: $(head -2 /tmp/pap-validate-err 2>/dev/null | tr '\n' ' ')"
      break
    fi
  done
fi

# 4. Git repo health (git op test)
if [ -z "$FAIL_REASON" ]; then
  if ! git -C "$MARVIN_DIR" log -1 --oneline >/dev/null 2>/tmp/pap-validate-err; then
    FAIL_FILE="git"
    FAIL_REASON="repo unreadable: $(head -2 /tmp/pap-validate-err 2>/dev/null | tr '\n' ' ')"
  fi
fi

# All checks passed — update last-good baseline and exit
if [ -z "$FAIL_REASON" ]; then
  log "All validation checks passed (HEAD=${CURRENT_HEAD:0:7})"
  [ -n "$CURRENT_HEAD" ] && echo "$CURRENT_HEAD" > "$LAST_GOOD_FILE"
  exit 0
fi

# Validation failed — attempt auto-revert
log "VALIDATION FAILED: $FAIL_FILE — $FAIL_REASON"

REVERTED_TO=""
if [ -n "$LAST_GOOD" ] && [ "$LAST_GOOD" != "$CURRENT_HEAD" ]; then
  # Only revert if tracked files have no uncommitted modifications (untracked files are fine)
  if git -C "$MARVIN_DIR" diff --quiet HEAD 2>/dev/null; then
    log "Auto-reverting to last known-good commit: ${LAST_GOOD:0:7}"
    if git -C "$MARVIN_DIR" reset --hard "$LAST_GOOD" 2>/tmp/pap-revert-err; then
      REVERTED_TO="$LAST_GOOD"
      log "Reverted to ${LAST_GOOD:0:7} successfully"
    else
      log "ERROR: git reset --hard failed: $(head -2 /tmp/pap-revert-err 2>/dev/null)"
    fi
  else
    log "Tracked files have uncommitted changes — skipping auto-revert to avoid data loss"
  fi
else
  log "No prior baseline to revert to (same commit or first run)"
fi

# Post failure notification to pap-improvements
TS=$(date "+%Y-%m-%d %H:%M %Z")
SHORT_REASON=$(echo "$FAIL_REASON" | cut -c1-140)
if [ -n "$REVERTED_TO" ]; then
  SHORT_HASH="${REVERTED_TO:0:7}"
  MSG="⚠️ **Update failed** [$TS] — \`$FAIL_FILE\`: $SHORT_REASON. Rolled back to \`$SHORT_HASH\`. Nothing was lost."
else
  MSG="⚠️ **Update failed** [$TS] — \`$FAIL_FILE\`: $SHORT_REASON. No rollback baseline — manual fix needed."
fi

post_discord "$PAP_IMPROVEMENTS" "$MSG"
log "Failure notification posted to pap-improvements"

exit 1
