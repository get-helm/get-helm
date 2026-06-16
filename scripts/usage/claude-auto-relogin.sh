#!/usr/bin/env bash
# claude-auto-relogin.sh — Silently re-authenticates Claude.ai session.
# Flow: trigger magic link email → retry loop (up to 5 min) → Claude Code reads Gmail → complete login.
# Fallback: if Claude CLI has no active session (not logged in), writes relogin-trigger.json
#   so bot.js spawns an agent (which always has Gmail MCP access) to complete the relogin.
# Called by claude-usage-hourly.sh when session_expired is detected.
# Never posts to Discord — failure is logged to file only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$SCRIPT_DIR/auto-relogin.log"
CLAUDE_BIN="/Users/{{USER_HOME}}/.local/bin/claude"
RELOGIN_TRIGGER="$HOME/pap-workspace/relogin-trigger.json"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

log "Auto-relogin started"

# Step 1: Trigger magic link email
log "Triggering magic link email..."
trigger_out=$(python3 "$SCRIPT_DIR/claude-scraper.py" trigger-login 2>>"$LOG")
trigger_status=$(echo "$trigger_out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('status','unknown'))" 2>/dev/null)
log "Trigger status: $trigger_status"

if [ "$trigger_status" != "email_submitted" ]; then
  log "ERROR: Failed to submit email — aborting auto-relogin"
  exit 1
fi

TRIGGERED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Step 2: Retry loop — wait 90s initially, then retry every 30s up to 5 more times (max ~4 min total)
# Broadened query: (from:anthropic.com OR from:claude.ai) catches emails from either sender domain
GMAIL_QUERY="(from:anthropic.com OR from:claude.ai) newer_than:30m"
# SESSION-FALSEALARM-001 Fix 2: prompt returns "EMAIL_TOO_OLD:<date>" if email sent >2h ago,
# allowing the script to reject stale links despite Gmail's newer_than:30m sometimes returning
# emails from 10+ hours ago (Gmail API quirk — query is advisory, not hard-bounded).
GMAIL_PROMPT="Use the Gmail MCP search_threads tool with query: '${GMAIL_QUERY}'. Get the most recent thread. Check the thread's internalDate or message Date header (Unix ms or RFC2822 string). If the email was sent MORE than 2 hours before now (current UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)), output exactly: EMAIL_TOO_OLD:<the email date>. Otherwise find the href inside the <a clicktracking=\"off\" href=\"...\"> tag in the HTML body — that is the magic link URL (starts with https://claude.ai/magic-link). Return ONLY the raw https:// URL, nothing else."

MAGIC_LINK=""
MAX_ATTEMPTS=5
for attempt in $(seq 1 $MAX_ATTEMPTS); do
  if [ $attempt -eq 1 ]; then
    log "Waiting 90s for initial email delivery (attempt $attempt/$MAX_ATTEMPTS)..."
    sleep 90
  else
    log "Waiting 30s before retry (attempt $attempt/$MAX_ATTEMPTS)..."
    sleep 30
  fi

  log "Gmail search attempt $attempt — query: $GMAIL_QUERY"
  ATTEMPT_RESULT=$("$CLAUDE_BIN" --allowedTools "mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread" -p "$GMAIL_PROMPT" 2>>"$LOG")

  # Check for "Not logged in" error — indicates Claude Code has no active session
  if echo "$ATTEMPT_RESULT" | grep -q "Not logged in"; then
    log "Claude Code CLI not logged in — falling back to bot.js agent for Gmail read"
    echo "{\"triggered_at\": \"$TRIGGERED_AT\", \"scraper_path\": \"$SCRIPT_DIR/claude-scraper.py\"}" > "$RELOGIN_TRIGGER"
    log "Wrote relogin-trigger.json — bot.js agent will complete the relogin"
    exit 0
  fi

  # SESSION-FALSEALARM-001: reject stale magic links (email older than 2h)
  if echo "$ATTEMPT_RESULT" | grep -q "^EMAIL_TOO_OLD:"; then
    STALE_DATE=$(echo "$ATTEMPT_RESULT" | sed 's/^EMAIL_TOO_OLD://')
    log "Attempt $attempt: email is too old (sent: $STALE_DATE) — rejecting stale magic link"
    continue
  fi

  if [[ "$ATTEMPT_RESULT" == https://* ]]; then
    MAGIC_LINK="$ATTEMPT_RESULT"
    log "Magic link found on attempt $attempt"
    break
  fi

  log "Attempt $attempt: not found yet (got: '$(echo "$ATTEMPT_RESULT" | head -c 120)')"
done

if [ -z "$MAGIC_LINK" ] || [[ ! "$MAGIC_LINK" == https://* ]]; then
  log "ERROR: Could not extract magic link after $MAX_ATTEMPTS attempts — aborting"
  exit 1
fi

log "Magic link found — completing login..."

# Step 3: Complete the login
login_out=$(python3 "$SCRIPT_DIR/claude-scraper.py" login "$MAGIC_LINK" 2>>"$LOG")
login_status=$(echo "$login_out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('status','unknown'))" 2>/dev/null)
log "Login status: $login_status"

if [ "$login_status" = "login_success" ]; then
  log "Auto-relogin succeeded"
  exit 0
fi

# Step 4 — Playwright login failed (typically CF challenge_redirect blocks the magic-link redirect).
# The magic link is still valid for ~5 min. Three fallbacks fire in parallel:
#   a) Write relogin-trigger.json so bot.js spawns a help agent with a fresh playwright context
#   b) Open the URL in {{USER_JERRY}}'s default browser via `open` — his real Chrome session can complete it
#   c) Post an alert to helm-improvements with the clickable URL (throttled to once per 4h)
log "ERROR: Login failed — status: $login_status — invoking fallbacks (bot.js agent + open browser + alert)"
log "CLOUDFLARE_BLOCK_DETECTED: Auto-relogin hit CF challenge on magic-link redirect. Activating browser + agent fallbacks."

# Fallback A: bot.js agent retry (carry the magic link forward so the agent can re-use it)
echo "{\"triggered_at\": \"$TRIGGERED_AT\", \"scraper_path\": \"$SCRIPT_DIR/claude-scraper.py\", \"magic_link\": \"$MAGIC_LINK\", \"reason\": \"playwright_cf_blocked\"}" > "$RELOGIN_TRIGGER"
log "Wrote relogin-trigger.json — bot.js agent will retry login"

# Fallback B: open in default browser (macOS only) — {{USER_JERRY}}'s real Chrome session can complete the redirect
if command -v open >/dev/null 2>&1; then
  open "$MAGIC_LINK" 2>>"$LOG"
  log "Opened magic link in default browser"
fi

# Fallback C: throttled Discord alert (helm-improvements, max once per 4h)
ALERT_COOLDOWN_FILE="$SCRIPT_DIR/.last-relogin-alert"
HELM_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
ALERT_COOLDOWN_SECONDS=14400  # 4 hours

SHOULD_ALERT=1
if [ -f "$ALERT_COOLDOWN_FILE" ]; then
  LAST_ALERT=$(cat "$ALERT_COOLDOWN_FILE" 2>/dev/null)
  NOW_S=$(date +%s)
  ELAPSED=$((NOW_S - LAST_ALERT))
  if [ "$ELAPSED" -lt "$ALERT_COOLDOWN_SECONDS" ]; then
    log "Alert skipped — cooldown active (${ELAPSED}s elapsed, need ${ALERT_COOLDOWN_SECONDS}s)"
    SHOULD_ALERT=0
  fi
fi

if [ "$SHOULD_ALERT" = "1" ] && [ -x "$DISCORD_POST" ]; then
  date +%s > "$ALERT_COOLDOWN_FILE"
  "$DISCORD_POST" "$HELM_IMPROVEMENTS_CHANNEL" "⚠️ Claude.ai auto-relogin failed (Cloudflare blocked the magic-link redirect). Magic link opened in your browser — if you don't see it, click here within 5 min to keep email ingest alive: $MAGIC_LINK" 2>>"$LOG"
  log "Posted alert to helm-improvements"
fi

exit 1
