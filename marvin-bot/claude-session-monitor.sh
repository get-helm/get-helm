#!/usr/bin/env bash
# claude-session-monitor.sh — Proactive Claude CLI auth health monitor
# Runs every 2 hours via cron. Detects auth failures before they cause silence.
# Recovery flow: detect → refresh → fallback to magic-link → alert if all fail.
# Never posts to Discord unless relogin completely fails.

CLAUDE_BIN="${HOME}/.local/bin/claude"
SCRAPER_DIR="${HOME}/helm-workspace/scripts/usage"
LOG="$SCRAPER_DIR/auto-relogin.log"
KEYCHAIN_SERVICE="Claude Code-credentials"
KEYCHAIN_ACCOUNT="$(whoami)"
RELOGIN_COOLDOWN_FILE="$SCRAPER_DIR/.last-relogin-attempted"
PROACTIVE_COOLDOWN_FILE="$SCRAPER_DIR/.last-proactive-refresh"
COOLDOWN_SECONDS=21600  # 6 hours between reactive relogin attempts
PROACTIVE_COOLDOWN_SECONDS=43200  # 12 hours between proactive refreshes (separate gate)
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
HELM_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [claude-session-monitor] $*" >> "$LOG"; }
log_audit() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [claude-session-monitor] $*" >> "$AUDIT_LOG"; }

log "Monitor started"

# ── STEP 1: Check OAuth access token expiry from keychain ─────────────────────
CREDS=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)
if [ -z "$CREDS" ]; then
  log "INFO: Keychain unavailable from cron — skipping token expiry check (live probe below is authoritative)"
else
  EXPIRES_AT=$(echo "$CREDS" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('claudeAiOauth',{}).get('expiresAt','0'))" 2>/dev/null)
  NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
  HOURS_LEFT=$(python3 -c "print(max(0, ($EXPIRES_AT - $NOW_MS) / 3600000))" 2>/dev/null)
  log "Access token expires in ${HOURS_LEFT}h"

  # ── PROACTIVE REFRESH: trigger relogin before expiry rather than after ────────
  HOURS_LEFT_INT=$(python3 -c "print(int(float('${HOURS_LEFT:-999}')))" 2>/dev/null)
  if [ -n "$HOURS_LEFT_INT" ] && [ "$HOURS_LEFT_INT" -lt 48 ] 2>/dev/null; then
    log "Proactive refresh: session expires in ${HOURS_LEFT}h (<48h threshold) — triggering relogin now"
    # Check separate proactive cooldown — not shared with reactive relogin gate
    SHOULD_REFRESH=1
    if [ -f "$PROACTIVE_COOLDOWN_FILE" ]; then
      LAST_ATTEMPT=$(cat "$PROACTIVE_COOLDOWN_FILE" 2>/dev/null)
      NOW_S=$(date +%s)
      ELAPSED=$((NOW_S - LAST_ATTEMPT))
      if [ "$ELAPSED" -lt "$PROACTIVE_COOLDOWN_SECONDS" ]; then
        log "Proactive refresh skipped — proactive cooldown active (${ELAPSED}s elapsed, need ${PROACTIVE_COOLDOWN_SECONDS}s)"
        SHOULD_REFRESH=0
      fi
    fi
    if [ "$SHOULD_REFRESH" = "1" ]; then
      date +%s > "$PROACTIVE_COOLDOWN_FILE"
      RELOGIN_RESULT=$(bash "$SCRAPER_DIR/claude-auto-relogin.sh" 2>&1)
      RELOGIN_EXIT=$?
      if [ $RELOGIN_EXIT -eq 0 ]; then
        log "Proactive refresh succeeded — scheduling next renewal warnings"
        bash "$HOME/marvin-bot/schedule-next-renewal.sh" >> "$LOG" 2>&1
      else
        log "Proactive refresh failed — will retry next monitor cycle"
      fi
    fi
    exit 0
  fi
fi

# ── STEP 2: Live probe — does `claude -p "ok"` actually work? ─────────────────
# macOS has no `timeout` binary — use Python subprocess with timeout instead
PROBE=$(python3 -c "
import subprocess, sys
try:
    r = subprocess.run(['$CLAUDE_BIN', '-p', 'respond with the word ok'],
                       capture_output=True, text=True, timeout=60)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stdout.write(r.stderr)
        sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.stdout.write('probe_timeout_expired')
    sys.exit(1)
" 2>&1)
EXIT_CODE=$?

if echo "$PROBE" | grep -qi "^ok\b"; then
  log "Probe: PASS — CLI responding, subscription auth working"
  exit 0
fi

# Classify failure
if echo "$PROBE" | grep -qi "rate.?limit\|usage.?limit\|overload"; then
  log "Probe: WARN — rate limited (transient, not an auth failure)"
  exit 0
fi

if echo "$PROBE" | grep -qi "not logged in\|please run /login\|auth\|unauthorized\|401\|403\|session"; then
  log "Probe: FAIL — auth error detected: $(echo "$PROBE" | head -c 200)"
  AUTH_FAILED=1
elif [ $EXIT_CODE -ne 0 ]; then
  log "Probe: WARN — non-zero exit ($EXIT_CODE), output: $(echo "$PROBE" | head -c 200)"
  # Could be transient — retry once after 10s
  sleep 10
  PROBE2=$(python3 -c "
import subprocess, sys
try:
    r = subprocess.run(['$CLAUDE_BIN', '-p', 'respond with the word ok'],
                       capture_output=True, text=True, timeout=60)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stdout.write(r.stderr)
        sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.stdout.write('probe_timeout_expired')
    sys.exit(1)
" 2>&1)
  if echo "$PROBE2" | grep -qi "^ok\b"; then
    log "Probe: PASS on retry — transient failure, now OK"
    exit 0
  fi
  if echo "$PROBE2" | grep -qi "not logged in\|please run /login\|auth\|unauthorized\|401\|403"; then
    log "Probe: FAIL on retry — auth error confirmed"
    AUTH_FAILED=1
  else
    log "Probe: WARN on retry — unclear failure, not triggering relogin"
    exit 0
  fi
fi

if [ -z "$AUTH_FAILED" ]; then
  log "Probe: response unclear but not an auth error — skipping relogin"
  exit 0
fi

# ── STEP 3: Auth failed — check cooldown before attempting relogin ────────────
if [ -f "$RELOGIN_COOLDOWN_FILE" ]; then
  LAST_ATTEMPT=$(cat "$RELOGIN_COOLDOWN_FILE" 2>/dev/null)
  NOW=$(date +%s)
  ELAPSED=$((NOW - LAST_ATTEMPT))
  if [ "$ELAPSED" -lt "$COOLDOWN_SECONDS" ]; then
    log "Relogin skipped — cooldown active (${ELAPSED}s elapsed, need ${COOLDOWN_SECONDS}s)"
    exit 0
  fi
fi

log "Triggering auto-relogin..."
date +%s > "$RELOGIN_COOLDOWN_FILE"

# ── STEP 4: Attempt auto-relogin ─────────────────────────────────────────────
RELOGIN_RESULT=$(bash "$SCRAPER_DIR/claude-auto-relogin.sh" 2>&1)
RELOGIN_EXIT=$?

if [ $RELOGIN_EXIT -eq 0 ]; then
  # Re-probe after relogin
  sleep 5
  PROBE3=$(python3 -c "
import subprocess, sys
try:
    r = subprocess.run(['$CLAUDE_BIN', '-p', 'respond with the word ok'],
                       capture_output=True, text=True, timeout=60)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stdout.write(r.stderr)
        sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.stdout.write('probe_timeout_expired')
    sys.exit(1)
" 2>&1)
  if echo "$PROBE3" | grep -qi "^ok\b"; then
    log "Relogin succeeded — CLI responding normally"
    exit 0
  fi
fi

# ── STEP 5: Relogin failed — alert via helm-improvements (call-to-action) ────
# This is a real outage signal requiring manual action — goes to helm-improvements.
# Routine failures and recovery progress go to helm-audit.log only.
log "ERROR: Auto-relogin failed — alerting helm-improvements (manual login required)"
log_audit "ERROR: Auto-relogin failed — manual login required. Probe error: $(echo "$PROBE" | head -c 100)"
"$DISCORD_POST" "$HELM_IMPROVEMENTS_CHANNEL" "🚨 Claude CLI auth failed and auto-relogin could not recover. Manual login needed: run \`claude login\` on the Mac Mini. Error: $(echo "$PROBE" | head -c 100)" 2>/dev/null
exit 1
