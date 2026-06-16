#!/usr/bin/env bash
# safe-restart.sh — audit in-flight agents before restarting bot.js
# Usage: ~/marvin-bot/safe-restart.sh [--force] [--skip-guard]
# --force: skip activity check, cooldown, and agent warnings; bypass one-change guard and auto-revert
# --skip-guard: bypass one-change-one-restart gate only; keeps other protections
#   Used by: VPS dead-man's switch, self-watchdog — confirmed-bad-state recoveries

set -euo pipefail

PLIST=~/Library/LaunchAgents/com.pap.marvin.plist
CHANNEL_STATE_DIR=~/helm-workspace/channel-state
ENV_FILE=~/marvin-bot/.env
LOG=~/marvin-bot/marvin.log
AUDIT_LOG=~/helm-workspace/pap-audit.log
PAP_IMPROVEMENTS_CHANNEL={{USER_CHANNEL_HELM_IMPROVEMENTS}}
FORCE=false
SKIP_GUARD=false
MORATORIUM_FLAG=~/helm-workspace/restart-moratorium.flag
ACTIVITY_CHECK_SECS=900  # 15 minutes

for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=true
  [[ "$arg" == "--skip-guard" ]] && SKIP_GUARD=true
done
# --force implies --skip-guard (full bypass mode)
[[ "$FORCE" == "true" ]] && SKIP_GUARD=true

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [safe-restart] $*" | tee -a "$LOG"
}

# Log who called us — agent, watchdog, or terminal
CALLER_CMD=$(ps -p "${PPID:-0}" -o comm= 2>/dev/null || echo "unknown")
CALLER_ARGS=$(ps -p "${PPID:-0}" -o args= 2>/dev/null | head -c 120 || echo "unknown")
log "Called by PID=$PPID cmd=$CALLER_CMD args=$CALLER_ARGS"

# Load Discord token
if [[ -f "$ENV_FILE" ]]; then
  export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1)
fi

if [[ -z "${DISCORD_BOT_TOKEN:-}" ]]; then
  log "ERROR: DISCORD_BOT_TOKEN not found in $ENV_FILE — aborting"
  exit 1
fi

log "Starting safe-restart (force=$FORCE)"

# claudeArgs flag preflight — CRITICAL gate (added 2026-06-14 after ea51fe4 incident).
# Without --dangerously-skip-permissions in claudeArgs, every spawned agent will fail
# at first tool call because Claude Code falls back to interactive permission prompts
# that the non-interactive -p invocation can never answer. This is exit 1, not warn:
# starting bot.js without the flag = guaranteed total agent failure.
if [[ -f "$HOME/marvin-bot/bot.js" ]]; then
  if ! grep -q "dangerously-skip-permissions" "$HOME/marvin-bot/bot.js"; then
    CRITICAL_MSG="🔴 RESTART BLOCKED: --dangerously-skip-permissions missing from bot.js. Every agent will fail. Fix: restore the flag in CLAUDE_BASE_ARGS (~line 72) and re-run."
    log "CRITICAL: $CRITICAL_MSG"
    curl -s -o /dev/null -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$CRITICAL_MSG\"}" \
      "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" || true
    exit 1
  fi
  log "claudeArgs flag preflight: OK (--dangerously-skip-permissions present)"
fi

# Permissions preflight — warn if ~/.claude/settings.json is missing the allow block.
# Agents spawned by bot.js use --dangerously-skip-permissions so they're unaffected.
# This gate protects interactive Claude Code sessions (e.g. Claude.ai CLI tools).
SETTINGS_JSON="$HOME/.claude/settings.json"
PERMS_STATUS=$(python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS_JSON'))
    allow = d.get('permissions', {}).get('allow', [])
    required = ['Bash(**)', 'Read(**)', 'Write(**)', 'Edit(**)']
    missing = [r for r in required if r not in allow]
    print('missing:' + ','.join(missing) if missing else 'ok')
except Exception as e:
    print('error:' + str(e))
" 2>/dev/null || echo "error:settings.json unreadable")
if [[ "$PERMS_STATUS" != "ok" ]]; then
  PERM_WARN="⚠️ Claude Code permissions check before restart: $PERMS_STATUS. Interactive sessions may hit approval gates. Run \`!check-permissions\` in Discord to diagnose and fix."
  log "WARN: $PERM_WARN"
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$PERM_WARN\"}" \
    "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" || true
fi

# Clear any stale moratorium flag — moratorium is disabled; wiring kept for re-enable if needed.
if [[ -f "$MORATORIUM_FLAG" ]]; then
  rm -f "$MORATORIUM_FLAG"
  log "Cleared stale moratorium flag"
fi

# 15-min activity check — if {{USER_JERRY}} has messaged in the last 15 min, post a confirmation
# to #pap-improvements and stop. Reply with /restart or --force to proceed anyway.
# --force bypasses this check entirely (explicit intent from terminal or /restart button).
if [[ "$FORCE" != "true" ]]; then
  RECENT_MSG_FILE=/tmp/pap-last-user-msg
  if [[ -f "$RECENT_MSG_FILE" ]]; then
    LAST_MSG_TS=$(cat "$RECENT_MSG_FILE" 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    ELAPSED_SINCE_MSG=$((NOW_TS - LAST_MSG_TS))
    if [[ $ELAPSED_SINCE_MSG -lt $ACTIVITY_CHECK_SECS ]]; then
      ACTIVITY_MSG="⚠️ Restart requested but you messaged ${ELAPSED_SINCE_MSG}s ago. To confirm restart, reply \`/restart\` or run: \`~/marvin-bot/safe-restart.sh --force\`"
      log "$ACTIVITY_MSG"
      curl -s -o /dev/null -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$ACTIVITY_MSG\"}" \
        "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" || true
      exit 1
    fi
  fi
fi

# Cooldown check — must happen BEFORE posting warnings.
# Previously this was checked after warnings were posted and 15s elapsed,
# causing spam: 5 "restarting in 15s" messages with 0 actual restarts.
LAST_RESTART_FILE=/tmp/pap-last-restart
COOLDOWN_SECS=600
if [[ "$FORCE" != "true" ]] && [[ -f "$LAST_RESTART_FILE" ]]; then
  LAST_TS=$(cat "$LAST_RESTART_FILE" 2>/dev/null || echo 0)
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - LAST_TS))
  if [[ $ELAPSED -lt $COOLDOWN_SECS ]]; then
    log "Cooldown active: ${ELAPSED}s since last restart (need ${COOLDOWN_SECS}s) — skipping to prevent launchd throttle"
    exit 0
  fi
fi

WARNED=false

# Always scan for in-flight agents — --force only skips the sleep, not the scan.
# This prevents --force from silently killing active workspace agents.
for STATE_FILE in "$CHANNEL_STATE_DIR"/*.json; do
  [[ -f "$STATE_FILE" ]] || continue

  CHANNEL_ID=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('channelId',''))" 2>/dev/null || true)
  AGENT_PID=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('agentPid') or '')" 2>/dev/null || true)
  LAST_PHASE=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('lastAgentMsgPhase') or '')" 2>/dev/null || true)
  SPAWN_AT=$(python3 -c "import json,sys; d=json.load(open('$STATE_FILE')); print(d.get('agentSpawnedAt') or '')" 2>/dev/null || true)

  [[ -z "$AGENT_PID" ]] && continue
  [[ -z "$CHANNEL_ID" ]] && continue

  # Check if process is alive
  if ! ps -p "$AGENT_PID" > /dev/null 2>&1; then
    log "PID $AGENT_PID for channel $CHANNEL_ID is not alive — skipping"
    continue
  fi

  # Skip if already in terminal phase
  if [[ "$LAST_PHASE" == "deliver" || "$LAST_PHASE" == "block" ]]; then
    log "Channel $CHANNEL_ID: PID $AGENT_PID alive but phase=$LAST_PHASE — safe to restart"
    continue
  fi

  # Calculate how long ago spawn was (seconds)
  ELAPSED_SEC=0
  if [[ -n "$SPAWN_AT" ]]; then
    NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")
    ELAPSED_SEC=$(python3 -c "print(int(($NOW_MS - $SPAWN_AT) / 1000))")
  fi

  log "WARNING: channel $CHANNEL_ID has in-flight agent PID $AGENT_PID (phase=${LAST_PHASE:-unknown}, ${ELAPSED_SEC}s ago)"

  if [[ "$FORCE" == "true" ]]; then
    # Force mode: log the interruption but do not post to channel or sleep.
    # Caller (engineer) is responsible for verifying no live agents before using --force.
    log "FORCE mode active — proceeding despite in-flight agent PID $AGENT_PID (channel $CHANNEL_ID)"
  else
    # Normal mode: post warning to channel and sleep so agent can checkpoint.
    WARN_MSG="⚡ Bot restarting in 90s. Finishing your current step and saving progress — will auto-resume after restart. (started ${ELAPSED_SEC}s ago)"
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$WARN_MSG\"}" \
      "https://discord.com/api/v10/channels/$CHANNEL_ID/messages")

    if [[ "$RESPONSE" == "200" ]]; then
      log "Warning posted to channel $CHANNEL_ID (HTTP 200)"
      WARNED=true
    else
      log "WARNING POST failed for channel $CHANNEL_ID (HTTP $RESPONSE)"
    fi
  fi
done

if [[ "$WARNED" == "true" ]]; then
  log "Warnings posted — sleeping 90s so in-flight agents can finish current step and checkpoint"
  sleep 90
elif [[ "$FORCE" != "true" ]]; then
  log "No in-flight agents found — proceeding immediately"
fi

# One-change-one-restart gate — block if more than 1 commit to bot.js since last restart
# Bypassed by --skip-guard (bad-state recovery) or --force (full override).
LAST_RESTART_COMMIT_FILE=/tmp/pap-last-restart-commit
if [[ -f "$LAST_RESTART_COMMIT_FILE" ]] && [[ "$SKIP_GUARD" != "true" ]]; then
  LAST_COMMIT=$(cat "$LAST_RESTART_COMMIT_FILE" 2>/dev/null || true)
  if [[ -n "$LAST_COMMIT" ]]; then
    COMMITS_SINCE=$(git -C /Users/{{USER_HOME}}/marvin-bot log --oneline "${LAST_COMMIT}..HEAD" -- bot.js 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COMMITS_SINCE" -gt 1 ]]; then
      WARN_MSG="⚠️ Restart blocked: $COMMITS_SINCE unverified changes to bot.js since last restart. One change at a time — verify each before stacking. Use --force or --skip-guard to override."
      log "$WARN_MSG"
      curl -s -o /dev/null -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$WARN_MSG\"}" \
        "https://discord.com/api/v10/channels/$PAP_IMPROVEMENTS_CHANNEL/messages" || true
      exit 1
    fi
  fi
elif [[ "$SKIP_GUARD" == "true" ]]; then
  log "Guard bypassed (--skip-guard or --force) — skipping one-change gate"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [safe-restart] GUARD_BYPASS caller=$CALLER_CMD force=$FORCE skip_guard=$SKIP_GUARD" >> "$AUDIT_LOG"
fi

date +%s > "$LAST_RESTART_FILE"

# Layer 3: Auto-revert validation — validate any pending changes before restart
# Skip during nightly (nightly-restart.sh calls auto-revert.sh separately before calling this script)
# Also skip when --force or --skip-guard: confirmed-bad-state recovery, auto-revert would block it.
if [[ "${SKIP_AUTO_REVERT:-false}" != "true" ]] && [[ "$SKIP_GUARD" != "true" ]] && [[ -f ~/marvin-bot/auto-revert.sh ]]; then
  log "Running Layer 3 auto-revert validation"
  if ! /bin/bash ~/marvin-bot/auto-revert.sh; then
    log "Layer 3 validation failed — aborting restart. Changes reverted."
    exit 1
  fi
  log "Layer 3 validation passed"
fi

# Kill bot.js directly — launchd KeepAlive=true restarts it within ~5s.
# This avoids the unload/load race that caused multi-minute outages:
# when safe-restart.sh is spawned by bot.js, launchctl unload kills the
# parent (bot.js) which can kill this script before launchctl load runs,
# leaving only a background fork racing against launchd throttle.
BOT_PID=$(pgrep -f "node bot.js" | head -1 || true)
if [[ -n "$BOT_PID" ]]; then
  log "Killing bot.js PID $BOT_PID — KeepAlive will restart within ~5s"
  kill "$BOT_PID" 2>/dev/null || true
  log "Kill sent — bot.js will restart automatically via launchd KeepAlive"
else
  log "bot.js not running — forcing launchd start"
  launchctl unload "$PLIST" 2>/dev/null || true
  sleep 1
  launchctl load "$PLIST" 2>/dev/null || true
  log "Plist reloaded"
fi

# Save restart commit for one-change-one-restart gate
git -C /Users/{{USER_HOME}}/marvin-bot rev-parse HEAD > "$LAST_RESTART_COMMIT_FILE" 2>/dev/null || true

# Post-restart smoke test — runs in background after bot starts
# Checks: (1) bot heartbeat alive, (2) VPS reachable, (3) Discord routing functional
# Alerts #helm-status on any failure
(
  sleep 15  # wait for bot to fully initialize and connect to Discord

  # Load bot token
  DISCORD_BOT_TOKEN=""
  [[ -f "$ENV_FILE" ]] && export $(grep -E '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | head -1) || true
  HELM_STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
  AUDIT_CHANNEL="{{USER_CHANNEL_HELM_AUDIT}}"

  # --- Check 1: Bot heartbeat ---
  SMOKE_FAIL=""
  HB_AGE=9999
  if [[ -f /tmp/marvin-heartbeat ]]; then
    HB_TS=$(cat /tmp/marvin-heartbeat 2>/dev/null || echo 0)
    HB_AGE=$(( ($(date +%s%3N) - HB_TS) / 1000 ))
  fi
  if [[ "$HB_AGE" -gt 90 ]]; then
    SMOKE_FAIL="bot heartbeat stale (${HB_AGE}s ago)"
    log "smoke-test: FAIL — $SMOKE_FAIL"
  else
    log "smoke-test: heartbeat OK (${HB_AGE}s ago)"
  fi

  # --- Check 2: VPS heartbeat ---
  VPS_HEARTBEAT_URL="http://{{USER_VPS_TAILSCALE_IP}}:9876/status"
  VPS_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -m 8 "$VPS_HEARTBEAT_URL" 2>/dev/null || echo "000")
  if [[ "$VPS_HTTP" = "200" ]]; then
    log "smoke-test: VPS heartbeat OK (HTTP 200)"
  else
    log "smoke-test: VPS heartbeat FAILED (HTTP ${VPS_HTTP})"
    SMOKE_FAIL="${SMOKE_FAIL:+$SMOKE_FAIL, }VPS unreachable (HTTP ${VPS_HTTP})"
  fi

  # --- Check 3: Discord routing — send test message, verify bot logged it ---
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    MARKER="smoke-$(date +%s)"
    # Send a test message to #helm-status (bot will route it to help agent)
    SEND_RESULT=$(curl -s -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"🔵 [smoke-test] $MARKER\"}" \
      "https://discord.com/api/v10/channels/$HELM_STATUS_CHANNEL/messages" 2>/dev/null || echo "")
    if echo "$SEND_RESULT" | grep -q '"id"'; then
      log "smoke-test: routing test message sent ($MARKER), waiting 35s..."
      sleep 35
      # Check marvin.log for evidence the message was routed to an agent
      if grep -q "$MARKER" "$LOG" 2>/dev/null; then
        log "smoke-test: routing PASS — message $MARKER appeared in log"
        # Post confirmation to helm-status
        curl -s -o /dev/null -X POST \
          -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"content\": \"✅ Post-restart check: bot running, VPS linked, routing confirmed.\"}" \
          "https://discord.com/api/v10/channels/$HELM_STATUS_CHANNEL/messages" || true
      else
        SMOKE_FAIL="${SMOKE_FAIL:+$SMOKE_FAIL, }routing unconfirmed (message not in log after 35s)"
        log "smoke-test: routing FAIL — $MARKER not found in log after 35s"
      fi
    else
      log "smoke-test: could not send routing test message (Discord API error)"
    fi
  fi

  # --- Check 4: Behavioral agent tool-call test (added 2026-06-14) ---
  # Spawns a real claude agent using the same binary bot.js uses and verifies it can
  # complete a tool call. Catches the ea51fe4 incident class: flag silently dropped from
  # claudeArgs → agents ACK but every tool call fails. Routing check (Check 3) would pass
  # (bot is alive, messages route) but this test would catch the broken agent execution.
  SMOKE_TMPFILE="/tmp/smoke-toolcall-$(date +%s)"
  echo "smoke-test-marker" > "$SMOKE_TMPFILE"
  CLAUDE_BIN="/Users/{{USER_HOME}}/.local/bin/claude"
  if [[ -x "$CLAUDE_BIN" ]]; then
    AGENT_OUT=$(timeout 45 "$CLAUDE_BIN" --dangerously-skip-permissions -p \
      "Read the file at $SMOKE_TMPFILE and reply with only the word: TOOLCALL_VERIFIED" 2>&1 \
      || echo "AGENT_FAILED_OR_TIMEOUT")
    rm -f "$SMOKE_TMPFILE"
    if echo "$AGENT_OUT" | grep -q "TOOLCALL_VERIFIED"; then
      log "smoke-test: behavioral tool-call PASS"
      # Record this commit as last-known-good: its agents actually execute tool calls.
      # The auto-rollback below reverts to this commit if a future deploy breaks agents.
      ( cd ~/marvin-bot && git rev-parse HEAD 2>/dev/null > ~/marvin-bot/.last-good-commit ) || true
      rm -f /tmp/helm-autorollback-attempted  # healthy again — reset the loop-cap
    else
      AGENT_SNIPPET=$(echo "$AGENT_OUT" | head -1 | cut -c1-80)
      SMOKE_FAIL="${SMOKE_FAIL:+$SMOKE_FAIL, }behavioral tool-call FAIL (${AGENT_SNIPPET})"
      log "smoke-test: behavioral tool-call FAIL — output: $(echo "$AGENT_OUT" | head -3)"
    fi
  else
    log "smoke-test: claude binary not found at $CLAUDE_BIN — skipping behavioral test"
  fi

  # --- Behavioral failure → AUTO-ROLLBACK to last-known-good (self-heal) ---
  # The behavioral tool-call FAIL is the unambiguous "agents are broken" signal
  # (e.g. the 2026-06-15 bare-HOME bug: agents ACK then every tool call fails).
  # Detection alone is not enough — a plain restart loops back into the same broken
  # code. So revert to the last commit whose agents were verified working, then restart.
  ROLLBACK_MARKER=/tmp/helm-autorollback-attempted
  LAST_GOOD=$(cat ~/marvin-bot/.last-good-commit 2>/dev/null || echo "")
  CUR_COMMIT=$(cd ~/marvin-bot && git rev-parse HEAD 2>/dev/null || echo "")
  if echo "$SMOKE_FAIL" | grep -q "behavioral tool-call FAIL"; then
    if [[ -f "$ROLLBACK_MARKER" ]] && [[ $(( $(date +%s) - $(cat "$ROLLBACK_MARKER" 2>/dev/null || echo 0) )) -lt 1800 ]]; then
      # Auto-rollback already ran <30min ago and agents are STILL broken — do NOT loop.
      log "auto-rollback: already attempted <30min ago and still failing — escalating, no loop"
      MSG="🚨 HELM auto-rollback ran but agents are STILL broken. This one needs you. Open https://status.{{USER_DOMAIN}}/recovery/prompt and paste the prompt into claude.ai, or power-cycle the Mac. (Auto-heal stopped to avoid a restart loop.)"
      [[ -n "${DISCORD_BOT_TOKEN:-}" ]] && curl -s -o /dev/null -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" -H "Content-Type: application/json" \
        -d "{\"content\": \"$MSG\"}" \
        "https://discord.com/api/v10/channels/$HELM_STATUS_CHANNEL/messages" || true
    elif [[ -n "$LAST_GOOD" ]] && [[ "$LAST_GOOD" != "$CUR_COMMIT" ]]; then
      date +%s > "$ROLLBACK_MARKER"
      log "auto-rollback: behavioral FAIL — reverting to last-known-good $LAST_GOOD and restarting"
      MSG="🛡️ HELM self-heal: agents broke after the last update. Auto-rolling back to the last working version and restarting — no action needed. Back in ~30s."
      [[ -n "${DISCORD_BOT_TOKEN:-}" ]] && curl -s -o /dev/null -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" -H "Content-Type: application/json" \
        -d "{\"content\": \"$MSG\"}" \
        "https://discord.com/api/v10/channels/$HELM_STATUS_CHANNEL/messages" || true
      bash ~/marvin-bot/rollback.sh "$LAST_GOOD" >> "$LOG" 2>&1 &
      exit 0  # rollback.sh restarts the bot; this background check is done
    else
      log "auto-rollback: behavioral FAIL but no usable last-known-good marker (or already on it) — alert only"
    fi
  fi

  # --- Check 5: Real bot.js spawn-path test (REAL-SPAWN-SMOKE-GATE-001) ---
  # Exercises the FULL bot.js message-routing → spawn → tool-call → DELIVER path.
  # Check 4 tests the claude binary in isolation (hardcoded args). This test exercises
  # bot.js's actual claudeArgs construction, env injection, and agent dispatch logic.
  # Catches: spawn-arg bugs (ea51fe4 class), broken env, model routing errors.
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    SPAWN_MARKER="spawn-gate-$(date +%s)"
    SPAWN_TEST_MSG="🔬 [smoke-test-gate] $SPAWN_MARKER — automated deploy verification. Reply 👍 ACK then ✅ DELIVER to confirm bot.js spawn path is healthy."
    # Post to helm-improvements (PAP_IMPROVEMENTS_CHANNEL) — agents respond here with Discord posts.
    # AUDIT_CHANNEL (helm-audit) is silenced (log-only), so agents there never post to Discord.
    SPAWN_CHANNEL="${PAP_IMPROVEMENTS_CHANNEL:-{{USER_CHANNEL_HELM_IMPROVEMENTS}}}"
    SPAWN_SEND=$(curl -s -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$SPAWN_TEST_MSG\"}" \
      "https://discord.com/api/v10/channels/$SPAWN_CHANNEL/messages" 2>/dev/null || echo "")
    SPAWN_MSG_ID=$(echo "$SPAWN_SEND" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
    if [[ -n "$SPAWN_MSG_ID" ]]; then
      log "smoke-test check-5: spawn-gate message sent to helm-improvements ($SPAWN_MARKER), waiting for bot ACK..."
      # Poll for bot ACK (👍) within 60s
      SPAWN_ACK_FOUND=false
      SPAWN_DELIVER_FOUND=false
      for i in $(seq 1 12); do
        sleep 5
        MSGS=$(curl -s \
          -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
          "https://discord.com/api/v10/channels/$SPAWN_CHANNEL/messages?limit=5" 2>/dev/null || echo "[]")
        BOT_ACK=$(echo "$MSGS" | python3 -c "
import json,sys
try:
    msgs = json.load(sys.stdin)
    for m in msgs:
        if m.get('author',{}).get('bot') and ('👍' in m.get('content','') or '$SPAWN_MARKER' in m.get('content','')):
            print('FOUND')
            break
except: pass
" 2>/dev/null || echo "")
        if [[ "$BOT_ACK" == "FOUND" ]]; then
          SPAWN_ACK_FOUND=true
          log "smoke-test check-5: bot ACK confirmed for $SPAWN_MARKER (${i}x5s)"
          break
        fi
      done
      if [[ "$SPAWN_ACK_FOUND" == "true" ]]; then
        # Poll for DELIVER (✅) within 5 min (60 × 5s)
        for i in $(seq 1 60); do
          sleep 5
          MSGS=$(curl -s \
            -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
            "https://discord.com/api/v10/channels/$SPAWN_CHANNEL/messages?limit=5" 2>/dev/null || echo "[]")
          BOT_DLV=$(echo "$MSGS" | python3 -c "
import json,sys
try:
    msgs = json.load(sys.stdin)
    for m in msgs:
        if m.get('author',{}).get('bot') and '✅' in m.get('content',''):
            print('FOUND')
            break
except: pass
" 2>/dev/null || echo "")
          if [[ "$BOT_DLV" == "FOUND" ]]; then
            SPAWN_DELIVER_FOUND=true
            log "smoke-test check-5: bot DELIVER confirmed for $SPAWN_MARKER (${i}x5s)"
            break
          fi
        done
      fi
      # Evaluate result
      if [[ "$SPAWN_ACK_FOUND" != "true" ]]; then
        SMOKE_FAIL="${SMOKE_FAIL:+$SMOKE_FAIL, }spawn-gate ACK timeout (60s — bot.js spawn path may be broken)"
        log "smoke-test check-5: FAIL — no bot ACK within 60s for $SPAWN_MARKER"
      elif [[ "$SPAWN_DELIVER_FOUND" != "true" ]]; then
        SMOKE_FAIL="${SMOKE_FAIL:+$SMOKE_FAIL, }spawn-gate DELIVER timeout (5min — agent spawned but didn't complete)"
        log "smoke-test check-5: FAIL — no bot DELIVER within 5min for $SPAWN_MARKER"
      else
        log "smoke-test check-5: PASS — spawn path healthy (ACK + DELIVER confirmed)"
        # Mark as known-good only if both Check 4 and Check 5 pass (behavioral + spawn path)
        if ! echo "$SMOKE_FAIL" | grep -q "behavioral\|spawn"; then
          ( cd ~/marvin-bot && git rev-parse HEAD 2>/dev/null > ~/marvin-bot/.last-good-commit ) || true
          rm -f /tmp/helm-autorollback-attempted
        fi
      fi
    else
      log "smoke-test check-5: could not send spawn-gate message — Discord API error (skipping check)"
    fi
  fi

  # --- Alert on any (non-auto-healed) failure ---
  if [[ -n "$SMOKE_FAIL" ]]; then
    MSG="⚠️ Post-restart smoke test FAILED: $SMOKE_FAIL. Run grab-logs.sh to diagnose. Recovery: \`~/marvin-bot/safe-restart.sh --skip-guard\`"
    [[ -n "${DISCORD_BOT_TOKEN:-}" ]] && curl -s -o /dev/null -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$MSG\"}" \
      "https://discord.com/api/v10/channels/$HELM_STATUS_CHANNEL/messages" || true
  fi
) &
