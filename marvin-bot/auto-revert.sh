#!/usr/bin/env bash
# auto-revert.sh — Pull updates with snapshot + automatic rollback on validation failure
# Usage: ~/marvin-bot/auto-revert.sh
# Called by nightly-restart.sh or safe-restart.sh BEFORE killing bot.js
# Snapshots critical files, pulls from GitHub, validates, reverts on failure

set -euo pipefail

MARVIN_BOT_DIR=~/marvin-bot
PAP_WORKSPACE=~/helm-workspace
SNAPSHOT_DIR=/tmp/pap-auto-revert-snapshot-$(date +%s)
LOG=~/marvin-bot/marvin.log
PAP_IMPROVEMENTS_CHANNEL={{USER_CHANNEL_HELM_IMPROVEMENTS}}
ENV_FILE=~/marvin-bot/.env

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [auto-revert] $*" | tee -a "$LOG"
}

post_discord() {
  local channel="$1"
  local msg="$2"
  [[ -z "${DISCORD_BOT_TOKEN:-}" ]] && return
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$msg\"}" \
    "https://discord.com/api/v10/channels/$channel/messages" || true
}

# Load Discord token
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

log "Auto-revert starting — creating snapshot before git pull"

# Create snapshot directory
mkdir -p "$SNAPSHOT_DIR"

# Snapshot critical files:
# 1. bot.js (main logic)
# 2. agents/*.md (agent definitions)
# 3. helm-workspace crucial files (scaffolder, curiosity, etc.)
log "Snapshotting bot.js"
cp ~/marvin-bot/bot.js "$SNAPSHOT_DIR/bot.js" || { log "ERROR: Failed to snapshot bot.js"; exit 1; }

log "Snapshotting agents/"
mkdir -p "$SNAPSHOT_DIR/agents"
cp ~/marvin-bot/agents/*.md "$SNAPSHOT_DIR/agents/" 2>/dev/null || log "Warning: Some agent files missing"

log "Snapshotting workspace critical files"
mkdir -p "$SNAPSHOT_DIR/workspace-critical"
for FILE in ~/.claude/agents/scaffolder.md ~/.claude/agents/curiosity.md ~/.claude/agents/executor.md; do
  [[ -f "$FILE" ]] && cp "$FILE" "$SNAPSHOT_DIR/workspace-critical/"
done

log "Snapshot created at: $SNAPSHOT_DIR"

# Fetch updates from GitHub
log "Pulling updates from origin/main"
cd ~/marvin-bot

# Stash local changes (e.g. agent-modified scripts) so git pull doesn't block
STASH_RESULT=$(git stash 2>&1)
STASHED=false
if echo "$STASH_RESULT" | grep -q "Saved working directory"; then
  STASHED=true
  log "Stashed local changes before pull: $STASH_RESULT"
fi

if ! git fetch origin main 2>&1 | tee -a "$LOG"; then
  log "ERROR: git fetch failed"
  [[ "$STASHED" == "true" ]] && git stash pop 2>/dev/null || true
  exit 1
fi

if ! git pull --rebase origin main 2>&1 | tee -a "$LOG"; then
  log "ERROR: git pull failed — reverting"
  git rebase --abort 2>/dev/null || true
  [[ "$STASHED" == "true" ]] && git stash pop 2>/dev/null || true
  exit 1
fi

# Restore local changes after successful pull
if [[ "$STASHED" == "true" ]]; then
  git stash pop 2>&1 | tee -a "$LOG" || log "Warning: stash pop failed — local changes may need manual restore"
fi

log "Git pull succeeded — starting validation"

# Validation suite — fail on ANY validation error
VALIDATION_FAILED=false

# 1. JavaScript syntax check (node --check)
log "Validating bot.js syntax"
NODE_BIN="${NODE_BIN:-/opt/homebrew/bin/node}"
if ! "$NODE_BIN" --check ~/marvin-bot/bot.js 2>&1 | tee -a "$LOG"; then
  log "VALIDATION FAILED: bot.js has syntax errors"
  VALIDATION_FAILED=true
fi

# 1b. claudeArgs flag check — CRITICAL behavioral validation (added 2026-06-14).
# Syntax-valid bot.js can still spawn agents that fail at first tool call if
# --dangerously-skip-permissions has been dropped from CLAUDE_BASE_ARGS / claudeArgs.
# This caught the ea51fe4 incident retroactively; now it gates every pull.
log "Validating --dangerously-skip-permissions present in claudeArgs"
if ! grep -q "dangerously-skip-permissions" ~/marvin-bot/bot.js; then
  log "VALIDATION FAILED: --dangerously-skip-permissions missing from bot.js — all agents would fail silently"
  VALIDATION_FAILED=true
fi

# 2. Agent file syntax (minimal check — files are YAML/text)
log "Validating agent files are readable"
for AGENT_FILE in ~/marvin-bot/agents/*.md; do
  [[ -f "$AGENT_FILE" ]] || continue
  if ! grep -q "^# " "$AGENT_FILE" 2>/dev/null; then
    log "VALIDATION FAILED: $AGENT_FILE missing header"
    VALIDATION_FAILED=true
  fi
done

# 3. Critical imports check (if bot.js imports external packages, verify they're installed)
log "Checking critical imports"
if grep -q "require('discord.js')" ~/marvin-bot/bot.js; then
  if ! ls ~/marvin-bot/node_modules/discord.js/package.json >/dev/null 2>&1; then
    log "VALIDATION FAILED: discord.js not installed"
    VALIDATION_FAILED=true
  fi
fi

# 4. Agent files check (existence, not corruption) — files live in ~/.claude/agents/
log "Validating workspace critical files"
for AGENT_FILE in ~/.claude/agents/scaffolder.md ~/.claude/agents/curiosity.md ~/.claude/agents/executor.md; do
  [[ -f "$AGENT_FILE" ]] || {
    log "VALIDATION FAILED: Missing critical agent file: $AGENT_FILE"
    VALIDATION_FAILED=true
  }
done

# 5. JSON validity check (if any .json files were modified)
log "Validating JSON files"
MODIFIED_JSON=$(git diff --name-only HEAD~1 2>/dev/null | grep -E '\.json$' || true)
for JSON_FILE in $MODIFIED_JSON; do
  [[ -f "$JSON_FILE" ]] && {
    if ! python3 -m json.tool "$JSON_FILE" > /dev/null 2>&1; then
      log "VALIDATION FAILED: Invalid JSON in $JSON_FILE"
      VALIDATION_FAILED=true
    fi
  }
done

# 6. Python syntax check (python -m py_compile for modified .py files)
log "Validating Python files"
MODIFIED_PY=$(git diff --name-only HEAD~1 2>/dev/null | grep -E '\.py$' || true)
for PY_FILE in $MODIFIED_PY; do
  [[ -f "$PY_FILE" ]] && {
    if ! python3 -m py_compile "$PY_FILE" 2>&1 | tee -a "$LOG"; then
      log "VALIDATION FAILED: Python syntax error in $PY_FILE"
      VALIDATION_FAILED=true
    fi
  }
done

# 7. Shell script syntax check (bash -n for modified .sh files)
log "Validating shell scripts"
MODIFIED_SH=$(git diff --name-only HEAD~1 2>/dev/null | grep -E '\.sh$' || true)
for SH_FILE in $MODIFIED_SH; do
  [[ -f "$SH_FILE" ]] && {
    if ! bash -n "$SH_FILE" 2>&1 | tee -a "$LOG"; then
      log "VALIDATION FAILED: Shell syntax error in $SH_FILE"
      VALIDATION_FAILED=true
    fi
  }
done

# 8. settings.json sanity check — verify it's valid JSON and has permissions block
log "Validating ~/.claude/settings.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  if ! python3 -m json.tool "$SETTINGS_FILE" > /dev/null 2>&1; then
    log "VALIDATION FAILED: ~/.claude/settings.json is invalid JSON — interactive sessions will hit permission gates"
    VALIDATION_FAILED=true
  else
    PERMS_PRESENT=$(python3 -c "import json; d=json.load(open('$SETTINGS_FILE')); print('ok' if d.get('permissions',{}).get('allow') else 'missing')" 2>/dev/null || echo "error")
    if [[ "$PERMS_PRESENT" != "ok" ]]; then
      log "WARN: ~/.claude/settings.json permissions.allow block is $PERMS_PRESENT — interactive sessions may hit permission gates (agents use --dangerously-skip-permissions, unaffected)"
    fi
  fi
fi

# 8b. Bare HOME reference check — catches path.join(HOME, ...) instead of path.join(config.HOME, ...)
# Symptom if missed: bot.js runs, agents initialize, then all fail with "HOME is not defined"
log "Checking for bare HOME references in bot.js"
if grep -n "path\.join(HOME," ~/marvin-bot/bot.js 2>/dev/null | grep -v "config\.HOME" | grep -q .; then
  BARE_REFS=$(grep -n "path\.join(HOME," ~/marvin-bot/bot.js | grep -v "config\.HOME" | head -5)
  log "VALIDATION FAILED: bare HOME reference(s) in bot.js — all agents will fail at runtime:"
  log "$BARE_REFS"
  VALIDATION_FAILED=true
fi

# If validation failed, revert from snapshot
if [[ "$VALIDATION_FAILED" == "true" ]]; then
  log "Validation failed — reverting from snapshot"

  # Revert bot.js
  log "Restoring bot.js from snapshot"
  cp "$SNAPSHOT_DIR/bot.js" ~/marvin-bot/bot.js || log "ERROR: Failed to restore bot.js"

  # Revert agents
  log "Restoring agents/ from snapshot"
  rm -f ~/marvin-bot/agents/*.md
  cp "$SNAPSHOT_DIR/agents/"*.md ~/marvin-bot/agents/ 2>/dev/null || log "Warning: Some agents not restored"

  # Hard reset git to pre-pull state
  log "Hard-resetting git to pre-pull state"
  cd ~/marvin-bot
  git reset --hard HEAD~1 2>&1 | tee -a "$LOG" || log "Warning: git reset may have issues"

  # Post failure notification to Discord
  FAILURE_MSG="🔴 **Auto-Revert Triggered** — Pull validation failed. Reverted to previous state. No changes deployed."
  log "$FAILURE_MSG"
  post_discord "$PAP_IMPROVEMENTS_CHANNEL" "$FAILURE_MSG"

  # Clean up snapshot
  rm -rf "$SNAPSHOT_DIR"

  exit 1
fi

log "Validation passed — changes are safe"
log "Snapshot saved at: $SNAPSHOT_DIR (will be cleaned up after successful restart)"

# Success: write snapshot path to a marker file so nightly-restart can clean up after verification
echo "$SNAPSHOT_DIR" > /tmp/pap-auto-revert-snapshot-path

exit 0
