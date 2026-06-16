#!/bin/bash
# pm-heartbeat.sh — Hourly health check to #pap-status
# Also performs auth-expiry check and alerts {{USER_JERRY}} via Discord + ntfy if session expired.

set -euo pipefail

WORKDIR="$HOME/helm-workspace"
AUTH_ALERT_STATE="$WORKDIR/channel-state/auth-alert-state.json"
PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"  # {{USER_JERRY}}'s main channel

# ── DISCORD_BOT_TOKEN ──────────────────────────────────────────────────────
source_token() {
  local token
  token=$(op item get "Discord Bot Token" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
  if [ -z "$token" ]; then
    token=$(grep '^DISCORD_BOT_TOKEN=' ~/marvin-bot/.env 2>/dev/null | cut -d= -f2- || echo "")
  fi
  echo "$token"
}

post_to_discord() {
  local channel="$1"
  local msg="$2"
  ~/marvin-bot/discord-post.sh "$channel" "$msg" 2>/dev/null || true
}

# ── AUTH STATE HELPERS ─────────────────────────────────────────────────────
read_alert_active() {
  python3 -c "
import json, os
f='$AUTH_ALERT_STATE'
if not os.path.exists(f): print('false'); exit()
d=json.load(open(f))
print('true' if d.get('alert_active') else 'false')
" 2>/dev/null || echo "false"
}

set_alert_state() {
  local active="$1"  # true or false
  python3 -c "
import json, time, os
f='$AUTH_ALERT_STATE'
d = json.load(open(f)) if os.path.exists(f) else {}
d['alert_active'] = $active
d['updated_at'] = time.time()
open(f,'w').write(json.dumps(d, indent=2))
" 2>/dev/null || true
}

# ── CLAUDE AUTH PROBE ──────────────────────────────────────────────────────
# Quick check: can Claude respond? Timeout 45s (same as pap-health-check.sh).
AUTH_STATUS="ok"
PROBE_OUTPUT=$(timeout 45 /opt/homebrew/bin/claude -p "respond with ok" 2>&1 || echo "PROBE_FAILED")

if echo "$PROBE_OUTPUT" | grep -qi "not logged in\|please run.*login\|session.*expired\|authentication failed\|401 unauthorized\|invalid.*token"; then
  AUTH_STATUS="expired"
elif echo "$PROBE_OUTPUT" | grep -qi "rate.?limit\|usage.?limit\|overload"; then
  AUTH_STATUS="rate_limited"
elif echo "$PROBE_OUTPUT" | grep -qi "PROBE_FAILED\|error\|failed\|timeout"; then
  AUTH_STATUS="unknown_error"
fi
# Any non-error response = ok (Claude responds with prose variations of "ok")

ALERT_CURRENTLY_ACTIVE=$(read_alert_active)

if [ "$AUTH_STATUS" = "expired" ]; then
  if [ "$ALERT_CURRENTLY_ACTIVE" != "true" ]; then
    # First detection — alert {{USER_JERRY}}
    echo "[pm-heartbeat] AUTH EXPIRED — posting alert to pap-improvements and ntfy"
    post_to_discord "$PAP_IMPROVEMENTS_CHANNEL" "⚠️ **Claude session expired** — agents will go silent until relogin. Use the **Status** button in #recovery or run \`/restart\` after logging back in at claude.ai."
    ~/marvin-bot/pap-notify-ntfy.sh "PAP Auth Expired" "Claude session expired — agents paused. Relogin needed." 2>/dev/null || true
    set_alert_state "True"
  else
    echo "[pm-heartbeat] Auth still expired (alert already sent, suppressing duplicate)"
  fi
elif [ "$AUTH_STATUS" = "ok" ]; then
  if [ "$ALERT_CURRENTLY_ACTIVE" = "true" ]; then
    # Auth recovered — self-healed event → audit log (not helm-improvements; per channel-consolidation directive)
    echo "[pm-heartbeat] Auth recovered — clearing alert"
    printf '[%s] [pm-heartbeat] ✅ Claude session restored — agents back online.\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true
    set_alert_state "False"
  fi
fi

# ── FULL HEALTH CHECK ──────────────────────────────────────────────────────
~/marvin-bot/pap-health-check.sh
