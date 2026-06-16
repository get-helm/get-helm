#!/usr/bin/env bash
# pap-health-check.sh — PAP component health check for #pap-status
# Posts a structured report covering core systems, automations, and workspaces.
# Usage: ./pap-health-check.sh [--quiet]   (--quiet: print only, no Discord post)

set -euo pipefail

STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
QUIET="${1:-}"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M %Z")
TODAY=$(date "+%Y-%m-%d")
PIN_ID_FILE="/Users/{{USER_HOME}}/marvin-bot/.pap-health-pin-id"

pass()  { echo "✅"; }
fail()  { echo "❌"; }
warn()  { echo "⚠️"; }
pause() { echo "⏸"; }

ISSUES=0

OFFLINE_FLAG="/tmp/pap-bot-was-offline"

# ── CORE SYSTEMS ─────────────────────────────────────────────────────────────

# Bot.js process — check via launchctl (launchd manages it, pgrep misses it)
BOT_STATUS=$(pass)
BOT_DETAIL=""
BOT_STATE=$(launchctl print gui/$(id -u)/com.pap.marvin 2>/dev/null | grep "state" | awk '{print $3}' || echo "")
BOT_PID=$(launchctl print gui/$(id -u)/com.pap.marvin 2>/dev/null | grep "^	pid" | awk '{print $3}' || echo "")
if [ "$BOT_STATE" != "running" ]; then
  BOT_STATUS=$(fail); ISSUES=$((ISSUES+1))
  BOT_DETAIL=" — not running"
  # Set offline flag so next run can post a recovery message
  touch "$OFFLINE_FLAG"
else
  BOT_UPTIME=$(ps -o etime= -p "$BOT_PID" 2>/dev/null | xargs || echo "unknown")
  BOT_DETAIL=" (up ${BOT_UPTIME})"
  # If we had a prior offline alert, post recovery and clear the flag
  if [ -f "$OFFLINE_FLAG" ]; then
    OFFLINE_SINCE=$(stat -f "%Sm" -t "%H:%M %Z" "$OFFLINE_FLAG" 2>/dev/null || echo "unknown time")
    RECOVERY_MSG="✅ Marvin recovered — bot.js is back online (was offline since ~${OFFLINE_SINCE}). launchd managed the restart. PID: ${BOT_PID}."
    DISCORD_BOT_TOKEN_TMP=$(grep '^DISCORD_BOT_TOKEN=' ~/marvin-bot/.env 2>/dev/null | cut -d= -f2- || echo "")
    [ -z "$DISCORD_BOT_TOKEN_TMP" ] && DISCORD_BOT_TOKEN_TMP=$(op item get "Discord Bot Token" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
    [ -n "$DISCORD_BOT_TOKEN_TMP" ] && curl -s -o /dev/null -X POST \
      "https://discord.com/api/v10/channels/{{USER_CHANNEL_HELM_STATUS}}/messages" \
      -H "Authorization: Bot ${DISCORD_BOT_TOKEN_TMP}" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"${RECOVERY_MSG}\"}" || true
    rm -f "$OFFLINE_FLAG"
    echo "[health-check] Posted bot recovery message (was offline since ~${OFFLINE_SINCE})"
  fi
fi

# Discord API + vault token
DISCORD_STATUS=$(pass)
DISCORD_DETAIL=""
VAULT_TOKEN=$(op item get "Discord Bot Token" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
DISCORD_BOT_TOKEN="$VAULT_TOKEN"
if [ -z "$DISCORD_BOT_TOKEN" ]; then
  DISCORD_BOT_TOKEN=$(grep '^DISCORD_BOT_TOKEN=' ~/marvin-bot/.env 2>/dev/null | cut -d= -f2- || echo "")
fi
if [ -z "$DISCORD_BOT_TOKEN" ]; then
  DISCORD_STATUS=$(fail); ISSUES=$((ISSUES+1))
  DISCORD_DETAIL=" — can't read token"
else
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    "https://discord.com/api/v10/users/@me" 2>/dev/null || echo "000")
  [ "$HTTP" != "200" ] && { DISCORD_STATUS=$(fail); ISSUES=$((ISSUES+1)); DISCORD_DETAIL=" — API returned $HTTP"; }
fi

# VPS connectivity
VPS_STATUS=$(pass)
VPS_DETAIL=""
VPS_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -m 8 "http://{{USER_VPS_TAILSCALE_IP}}:9876/heartbeat" 2>/dev/null || echo "000")
if [ "$VPS_HTTP" = "000" ]; then
  VPS_STATUS=$(fail); ISSUES=$((ISSUES+1))
  VPS_DETAIL=" — unreachable"
fi

# Vault accessible — 1Password preferred; .env fallback is acceptable
VAULT_STATUS=$(pass)
VAULT_DETAIL=""
if [ -n "$VAULT_TOKEN" ]; then
  VAULT_DETAIL=" (1Password)"
elif [ -n "$DISCORD_BOT_TOKEN" ]; then
  VAULT_DETAIL=" (.env fallback)"
else
  VAULT_STATUS=$(fail); ISSUES=$((ISSUES+1))
  VAULT_DETAIL=" — locked, no fallback"
fi

# Disk space
DISK_STATUS=$(pass)
DISK_DETAIL=""
DISK_PCT=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
DISK_AVAIL=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "?")
if [ "${DISK_PCT}" -gt 85 ] 2>/dev/null; then
  DISK_STATUS=$(fail); ISSUES=$((ISSUES+1))
  DISK_DETAIL=" — ${DISK_PCT}% used"
else
  DISK_DETAIL=" (${DISK_AVAIL} free)"
fi

# ── AUTOMATIONS ───────────────────────────────────────────────────────────────

# Daily brief — ran today?
BRIEF_STATUS=$(pass)
BRIEF_DETAIL=""
BRIEF_FILE=~/helm-workspace/daily-brief/briefings/${TODAY}.md
if [ -f "$BRIEF_FILE" ]; then
  BRIEF_TIME=$(date -r "$BRIEF_FILE" "+%I:%M%p" | tr '[:upper:]' '[:lower:]' | sed 's/^0//')
  BRIEF_DETAIL=" — ran today at ${BRIEF_TIME}"
else
  BRIEF_STATUS=$(warn)
  BRIEF_DETAIL=" — no brief found for today"
fi

# Nightly restart last run
RESTART_RUNS=$(launchctl print gui/$(id -u)/com.pap.nightly-restart 2>/dev/null | grep "^	runs" | awk '{print $3}' || echo "?")
RESTART_EXIT=$(launchctl print gui/$(id -u)/com.pap.nightly-restart 2>/dev/null | grep "last exit code" | awk '{print $5}' || echo "?")
RESTART_STATUS=$(pass)
RESTART_DETAIL=" (${RESTART_RUNS} runs, last exit ${RESTART_EXIT})"
[ "$RESTART_EXIT" != "0" ] && [ "$RESTART_EXIT" != "?" ] && { RESTART_STATUS=$(warn); }

# Watchdog active?
WATCHDOG_RUNS=$(launchctl print gui/$(id -u)/com.pap.watchdog 2>/dev/null | grep "^	runs" | awk '{print $3}' || echo "?")
WATCHDOG_STATUS=$(pass)
WATCHDOG_DETAIL=" (${WATCHDOG_RUNS} checks)"
[ "$WATCHDOG_RUNS" = "?" ] || [ "$WATCHDOG_RUNS" = "0" ] && { WATCHDOG_STATUS=$(warn); WATCHDOG_DETAIL=" — not active"; }

# ETF monthly pull — run count
ETF_PULL_RUNS=$(launchctl print gui/$(id -u)/com.pap.etf-monthly-pull 2>/dev/null | grep "^	runs" | awk '{print $3}' || echo "?")
ETF_PULL_STATUS=$(pass)
ETF_PULL_DETAIL=" (${ETF_PULL_RUNS} runs)"
if [ "$ETF_PULL_RUNS" = "0" ] || [ "$ETF_PULL_RUNS" = "?" ]; then
  ETF_PULL_STATUS=$(warn)
  ETF_PULL_DETAIL=" — never triggered (monthly, may be expected)"
fi

# Claude usage fetch — last result from hourly cron
CLAUDE_USAGE_STATUS=$(pass)
CLAUDE_USAGE_DETAIL=""
CLAUDE_USAGE_RESULT="$HOME/helm-workspace/scripts/usage/last-result.json"
CLAUDE_ERROR_STATE="$HOME/helm-workspace/scripts/usage/.last-error-posted"
if [ ! -f "$CLAUDE_USAGE_RESULT" ]; then
  CLAUDE_USAGE_STATUS=$(warn)
  CLAUDE_USAGE_DETAIL=" — no fetch result yet"
else
  CLAUDE_FETCH_ERR=$(python3 -c "
import json, os, time
d=json.load(open('$CLAUDE_USAGE_RESULT'))
err=d.get('error')
ts=d.get('ts','')
sonnet=d.get('sevenDaySonnetPct')
seven=d.get('sevenDayPct')
five=d.get('fiveHourPct')
if err and err != 'None':
    print(f'error:{err}')
elif ts:
    from datetime import datetime, timezone
    try:
        fetch_time = datetime.fromisoformat(ts.replace('Z','+00:00'))
        age_min = int((datetime.now(timezone.utc) - fetch_time).total_seconds() / 60)
        s5 = int(five) if five is not None else 'n/a'
        s7 = int(seven) if seven is not None else 'n/a'
        ss = int(sonnet) if sonnet is not None else 'n/a'
        print(f'ok:{age_min}:{s5}:{ss}:{s7}')
    except: print('ok:?:n/a:n/a:n/a')
else:
    print('ok:?:n/a:n/a:n/a')
" 2>/dev/null || echo "error:parse_failed")
  if echo "$CLAUDE_FETCH_ERR" | grep -q "^error:"; then
    ERR_VAL="${CLAUDE_FETCH_ERR#error:}"
    CLAUDE_USAGE_STATUS=$(fail); ISSUES=$((ISSUES+1))
    # Check if error is persisting (error state file exists)
    if [ -f "$CLAUDE_ERROR_STATE" ]; then
      LAST_ERR_TIME=$(cat "$CLAUDE_ERROR_STATE" 2>/dev/null || echo "0")
      MINS_SINCE=$(( ($(date +%s) - LAST_ERR_TIME) / 60 ))
      CLAUDE_USAGE_DETAIL=" — $ERR_VAL (failing for ~${MINS_SINCE}min)"
      # Log to pm-log.md when error has persisted >2hr — PM escalates to user if action needed
      ESCALATE_STATE="$HOME/helm-workspace/scripts/usage/.last-escalated"
      LAST_ESC=$(cat "$ESCALATE_STATE" 2>/dev/null || echo "0")
      if [ "$MINS_SINCE" -ge 120 ] 2>/dev/null && [ $(( $(date +%s) - LAST_ESC )) -gt 14400 ] 2>/dev/null; then
        echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [health-check] Claude usage fetch failing ~${MINS_SINCE}min (${ERR_VAL}) — session refresh may be needed" >> "$HOME/helm-workspace/pm-log.md"
        date +%s > "$ESCALATE_STATE"
      fi
    else
      CLAUDE_USAGE_DETAIL=" — $ERR_VAL"
    fi
  else
    AGE=$(echo "$CLAUDE_FETCH_ERR" | cut -d: -f2)
    FIVE_PCT=$(echo "$CLAUDE_FETCH_ERR" | cut -d: -f3)
    SONNET_PCT=$(echo "$CLAUDE_FETCH_ERR" | cut -d: -f4)
    SEVEN_PCT=$(echo "$CLAUDE_FETCH_ERR" | cut -d: -f5)
    if [ "$AGE" != "?" ] && [ "$AGE" -gt 90 ] 2>/dev/null; then
      CLAUDE_USAGE_STATUS=$(warn)
      CLAUDE_USAGE_DETAIL=" — last fetch ${AGE}min ago (stale)"
    else
      CLAUDE_USAGE_DETAIL=" — 5hr:${FIVE_PCT}% Sonnet:${SONNET_PCT}% 7d:${SEVEN_PCT}%"
    fi
  fi
fi

# Discord MCP availability — read last entry from mcp-availability.jsonl
MCP_STATUS=$(pass)
MCP_DETAIL=""
MCP_FILE="$HOME/helm-workspace/mcp-availability.jsonl"
if [ ! -f "$MCP_FILE" ]; then
  MCP_STATUS=$(warn)
  MCP_DETAIL=" — no data yet (PM hasn't made a MCP call)"
else
  MCP_RESULT=$(python3 -c "
import json, os
from datetime import datetime, timezone
f = os.path.expanduser('~/helm-workspace/mcp-availability.jsonl')
last = None
with open(f) as fh:
    for line in fh:
        line = line.strip()
        if line:
            try: last = json.loads(line)
            except: pass
if not last:
    print('no_data')
else:
    ts = last.get('ts','')
    success = last.get('success', False)
    try:
        dt = datetime.fromisoformat(ts.replace('Z','+00:00'))
        age_min = int((datetime.now(timezone.utc) - dt).total_seconds() / 60)
    except:
        age_min = -1
    print(f'{\"ok\" if success else \"fail\"}:{age_min}:{ts}')
" 2>/dev/null || echo "no_data")
  if [ "$MCP_RESULT" = "no_data" ]; then
    MCP_STATUS=$(warn)
    MCP_DETAIL=" — no entries found"
  elif echo "$MCP_RESULT" | grep -q "^ok:"; then
    AGE_MIN=$(echo "$MCP_RESULT" | cut -d: -f2)
    if [ "$AGE_MIN" -lt 60 ] 2>/dev/null; then
      MCP_DETAIL=" — last call ${AGE_MIN}min ago"
    else
      MCP_DETAIL=" — last success ${AGE_MIN}min ago"
    fi
  else
    MCP_STATUS=$(warn); ISSUES=$((ISSUES+1))
    AGE_MIN=$(echo "$MCP_RESULT" | cut -d: -f2)
    MCP_DETAIL=" — last call failed (${AGE_MIN}min ago)"
    # pap-status alert only — no ntfy (MCP unavailability is not user-actionable; hourly ntfy is pure noise)
  fi
fi

# ── WORKSPACES ────────────────────────────────────────────────────────────────

# ETF tracker site live?
ETF_SITE_STATUS=$(pass)
ETF_SITE_DETAIL=""
ETF_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -m 8 "https://etf.{{USER_DOMAIN}}/" 2>/dev/null || echo "000")
if [ "$ETF_HTTP" = "200" ]; then
  ETF_SITE_DETAIL=" — etf.{{USER_DOMAIN}} responding"
else
  ETF_SITE_STATUS=$(fail); ISSUES=$((ISSUES+1))
  ETF_SITE_DETAIL=" — site returned HTTP ${ETF_HTTP}"
fi

# Options helper — check for blocked/paused state
OPTIONS_STATUS=""
OPTIONS_DETAIL=""
OPTIONS_STATE=$(python3 -c "
import json, os
f=os.path.expanduser('~/helm-workspace/channel-state/1502485100976144434.json')
if not os.path.exists(f): print('unknown'); exit()
d=json.load(open(f))
cp=d.get('checkpoint',{})
if not cp: print('no active task'); exit()
cur=cp.get('currentStep',0); tot=cp.get('totalSteps',0)
req=cp.get('requestText','')[:50]
print(f'step {cur}/{tot}')
" 2>/dev/null || echo "unknown")
OPTIONS_STATUS=$(pause)
OPTIONS_DETAIL=" — awaiting your approval to proceed"

# Financial review — last known state
FINREV_STATE=$(python3 -c "
import json, os
f=os.path.expanduser('~/helm-workspace/channel-state/1504160847134720050.json')
if not os.path.exists(f): print('unknown'); exit()
d=json.load(open(f))
cp=d.get('checkpoint',{})
if not cp: print('idle'); exit()
cur=cp.get('currentStep',0); tot=cp.get('totalSteps',0)
if tot>0 and cur>=tot: print('last task complete')
else: print(f'step {cur}/{tot}')
" 2>/dev/null || echo "unknown")
FINREV_STATUS=$(pass)
FINREV_DETAIL=" — ${FINREV_STATE}"
if echo "$FINREV_STATE" | grep -q "^step "; then
  # In-progress task; fine but note it
  FINREV_DETAIL=" — in progress: ${FINREV_STATE}"
fi

# ── MAC MINI SECURITY POSTURE ────────────────────────────────────────────────

# FileVault encryption
FILEVAULT_STATUS=$(pass)
FILEVAULT_DETAIL=""
FV_STATE=$(fdesetup status 2>/dev/null | head -1 || echo "")
if echo "$FV_STATE" | grep -qi "FileVault is On"; then
  FILEVAULT_DETAIL=" — On"
else
  FILEVAULT_STATUS=$(warn); ISSUES=$((ISSUES+1))
  FILEVAULT_DETAIL=" — Off or unknown"
fi

# Display sleep timer (required for screen lock to work)
SLEEP_STATUS=$(pass)
SLEEP_DETAIL=""
DISPLAY_SLEEP=$(pmset -g 2>/dev/null | grep "displaysleep" | awk '{print $2}' || echo "")
if [ -z "$DISPLAY_SLEEP" ] || [ "$DISPLAY_SLEEP" = "0" ]; then
  SLEEP_STATUS=$(warn)
  SLEEP_DETAIL=" — not configured (screen won't auto-lock)"
else
  SLEEP_DETAIL=" — ${DISPLAY_SLEEP}min"
fi

# ── TURN HEALTH (from event-stream.jsonl, last 24h) ──────────────────────────

TURN_HEALTH=$(python3 -c "
import json, os
from datetime import datetime, timezone, timedelta
from collections import defaultdict

EVENT_STREAM = os.path.expanduser('~/helm-workspace/event-stream.jsonl')
WINDOW_H = 24
cutoff = datetime.now(timezone.utc) - timedelta(hours=WINDOW_H)

counts = defaultdict(int)
events_by_channel = defaultdict(list)
restart_times = []

if os.path.exists(EVENT_STREAM):
    with open(EVENT_STREAM) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: d = json.loads(line)
            except: continue
            ts_str = d.get('ts','')
            try:
                ts = datetime.fromisoformat(ts_str.replace('Z','+00:00'))
            except: continue
            if ts < cutoff: continue
            etype = d.get('type','unknown')
            counts[etype] += 1
            ch = d.get('channelId') or '__global__'
            events_by_channel[ch].append((ts, etype))
            if etype == 'bot_restart':
                restart_times.append(ts)

spawns = counts['agent_spawn']
delivers = counts['deliver_validated']
kills = counts['timeout_kill'] + counts['ack_kill']
restarts = counts['bot_restart']
repeats = counts['user_repeat']
rate = int(delivers / spawns * 100) if spawns > 0 else 0

# MTTR: avg seconds from bot_restart to first deliver_validated after it
mttr_samples = []
for rt in restart_times:
    # find next deliver_validated across any channel after this restart
    next_deliver = None
    for ch_events in events_by_channel.values():
        for ts, etype in sorted(ch_events):
            if ts > rt and etype == 'deliver_validated':
                if next_deliver is None or ts < next_deliver:
                    next_deliver = ts
                break
    if next_deliver:
        mttr_samples.append((next_deliver - rt).total_seconds())

mttr_str = 'n/a'
mttr_icon = '✅'
if mttr_samples:
    avg_mttr = sum(mttr_samples) / len(mttr_samples)
    mttr_str = f'{int(avg_mttr)}s avg'
    mttr_icon = '✅' if avg_mttr <= 120 else ('⚠️' if avg_mttr <= 300 else '❌')

rate_icon = '✅' if rate >= 85 else ('⚠️' if rate >= 60 else '❌')
kill_icon = '✅' if kills == 0 else ('⚠️' if kills <= 3 else '❌')
restart_icon = '✅' if restarts <= 2 else ('⚠️' if restarts <= 5 else '❌')
repeat_icon = '✅' if repeats == 0 else ('⚠️' if repeats <= 2 else '❌')

print(f'{rate_icon} Completion: {delivers}/{spawns} turns delivered ({rate}%)')
print(f'{kill_icon} Turn kills: {kills} (t/o={counts[\"timeout_kill\"]} ack={counts[\"ack_kill\"]})')
print(f'{restart_icon} Bot restarts: {restarts}')
print(f'{mttr_icon} MTTR: {mttr_str} ({len(mttr_samples)} samples)')
print(f'{repeat_icon} Repeated instructions: {repeats}')
" 2>/dev/null || echo "⚠️ Could not read event stream")

# ── RECOVERY STATE ───────────────────────────────────────────────────────────

# Check auto-revert status from marvin.log (last 24h)
RECOVERY_STATUS=$(pass)
RECOVERY_DETAIL=" — ✅ healthy"
RECOVERY_LOG=$(grep "\[auto-revert\]\|\[agent-resumption\]" ~/marvin-bot/marvin.log 2>/dev/null | tail -20 || echo "")
if echo "$RECOVERY_LOG" | grep -q "VALIDATION FAILED\|Auto-Revert Triggered"; then
  RECOVERY_STATUS=$(warn)
  RECOVERY_DETAIL=" — ⚠️ failover active (auto-revert triggered recently)"
  ISSUES=$((ISSUES+1))
elif echo "$RECOVERY_LOG" | grep -q "Hard-resetting git"; then
  RECOVERY_STATUS=$(fail)
  RECOVERY_DETAIL=" — 🔴 reverting (nothing lost — rolled back to last known good)"
  ISSUES=$((ISSUES+1))
fi

# Check last agent resumption
RESUME_DETAIL=""
LAST_RESUME=$(grep "\[agent-resumption\]" ~/marvin-bot/marvin.log 2>/dev/null | tail -3 | grep "triggered\|stalled" | head -1 || echo "")
if [ -n "$LAST_RESUME" ]; then
  RESUME_COUNT=$(echo "$LAST_RESUME" | grep -oE "[0-9]+ stalled" | grep -oE "[0-9]+" || echo "0")
  RESUME_DETAIL=" | Last resumption: ${RESUME_COUNT} agent(s)"
fi

# ── OVERALL STATUS ────────────────────────────────────────────────────────────

if [ "$ISSUES" -eq 0 ]; then
  HEADER="🟢 All systems working — ${TIMESTAMP}"
elif [ "$ISSUES" -le 2 ]; then
  HEADER="🟡 Minor issues — ${TIMESTAMP}"
else
  HEADER="🔴 Problems detected — ${TIMESTAMP}"
fi

MESSAGE="${HEADER}

Core
${BOT_STATUS} Bot${BOT_DETAIL}
${DISCORD_STATUS} Discord${DISCORD_DETAIL}
${VPS_STATUS} VPS${VPS_DETAIL}
${VAULT_STATUS} Vault${VAULT_DETAIL}
${DISK_STATUS} Disk${DISK_DETAIL}

Automations
${BRIEF_STATUS} Daily brief${BRIEF_DETAIL}
${RESTART_STATUS} Nightly restart${RESTART_DETAIL}
${WATCHDOG_STATUS} Watchdog${WATCHDOG_DETAIL}
${ETF_PULL_STATUS} ETF monthly pull${ETF_PULL_DETAIL}
${CLAUDE_USAGE_STATUS} Claude usage fetch${CLAUDE_USAGE_DETAIL}
${MCP_STATUS} Discord MCP${MCP_DETAIL}

Mac Mini
${FILEVAULT_STATUS} FileVault${FILEVAULT_DETAIL}
${SLEEP_STATUS} Sleep timer${SLEEP_DETAIL}

Turn Health (24h)
${TURN_HEALTH}

Workspaces
${ETF_SITE_STATUS} ETF tracker${ETF_SITE_DETAIL}
${OPTIONS_STATUS} Options helper${OPTIONS_DETAIL}
${FINREV_STATUS} Financial review${FINREV_DETAIL}

Recovery
${RECOVERY_STATUS} Auto-revert${RECOVERY_DETAIL}${RESUME_DETAIL}"

if [ "$QUIET" = "--quiet" ]; then
  echo "$MESSAGE"
  [ "$ISSUES" -eq 0 ] && exit 0 || exit 1
fi

# Read token for direct Discord API calls (needed for pin/patch)
DISCORD_BOT_TOKEN=$(grep '^DISCORD_BOT_TOKEN=' ~/marvin-bot/.env 2>/dev/null | cut -d= -f2- || echo "")
if [ -z "$DISCORD_BOT_TOKEN" ]; then
  DISCORD_BOT_TOKEN=$(op item get "Discord Bot Token" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
fi

# Escape message for JSON
ESCAPED_MESSAGE=$(echo "$MESSAGE" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" | sed 's/^"//;s/"$//')

# If we have a pinned message ID, patch it in-place; otherwise post + pin
if [ -n "$DISCORD_BOT_TOKEN" ] && [ -f "$PIN_ID_FILE" ]; then
  PINNED_MSG_ID=$(cat "$PIN_ID_FILE")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
    "https://discord.com/api/v10/channels/${STATUS_CHANNEL}/messages/${PINNED_MSG_ID}" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"${ESCAPED_MESSAGE}\"}")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "[health-check] Patched pinned message ${PINNED_MSG_ID} at $TIMESTAMP"
    [ "$ISSUES" -ge 3 ] && ~/marvin-bot/pap-notify-ntfy.sh "PAP Health Alert" "$(echo "$ISSUES") health checks failed. Check #pap-status." || true
    exit 0
  else
    echo "[health-check] Patch failed HTTP ${HTTP_CODE}, re-creating pin"
    rm -f "$PIN_ID_FILE"
  fi
fi

if [ -n "$DISCORD_BOT_TOKEN" ]; then
  # Post a new message and pin it
  RESPONSE=$(curl -s -X POST \
    "https://discord.com/api/v10/channels/${STATUS_CHANNEL}/messages" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"${ESCAPED_MESSAGE}\"}")
  MSG_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
  if [ -n "$MSG_ID" ]; then
    curl -s -o /dev/null -X PUT \
      "https://discord.com/api/v10/channels/${STATUS_CHANNEL}/pins/${MSG_ID}" \
      -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
      -H "Content-Length: 0"
    echo "$MSG_ID" > "$PIN_ID_FILE"
    echo "[health-check] Posted + pinned msg ${MSG_ID} at $TIMESTAMP"
  else
    echo "[health-check] ERROR posting: $RESPONSE"
    ~/marvin-bot/discord-post.sh "$STATUS_CHANNEL" "$MESSAGE"
  fi
else
  ~/marvin-bot/discord-post.sh "$STATUS_CHANNEL" "$MESSAGE"
  echo "[health-check] Posted at $TIMESTAMP (no token for pin)"
fi
