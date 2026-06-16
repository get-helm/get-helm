#!/usr/bin/env bash
# claude-usage-hourly.sh — Lightweight hourly Claude usage check.
# Fetches current session (5hr) + 7-day Sonnet via API (no browser).
# Posts compact status to #pap-status. Alerts at 80%.

CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISCORD="$HOME/marvin-bot/discord-post.sh"
ERROR_STATE_FILE="$SCRIPT_DIR/.last-error-posted"

# CONDITIONAL FETCH: Only run if user was active in past hour.
# Skips Keychain reads + API calls during idle periods. Override: always
# run if the last fetch had an error (need to clear the error state).
user_was_active() {
  python3 - <<'PYEOF' 2>/dev/null
import re, datetime, sys
from pathlib import Path
log_path = Path.home() / 'marvin-bot/marvin.log'
now = datetime.datetime.now(datetime.timezone.utc)
cutoff = now - datetime.timedelta(hours=1)
pattern = re.compile(r'^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})')
try:
    lines = log_path.read_text().splitlines()[-1000:]
except:
    sys.exit(0)  # can't read — assume active, let the fetch run
for line in reversed(lines):
    m = pattern.match(line)
    if m and '→' in line and '#' in line and '[watch' not in line and '[self' not in line:
        try:
            ts_str = m.group(1)
            ts = datetime.datetime.fromisoformat(ts_str + '+00:00')
            if ts > cutoff:
                sys.exit(0)  # active
        except:
            pass
sys.exit(1)  # idle
PYEOF
}

if ! user_was_active && [ ! -f "$ERROR_STATE_FILE" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | SKIP | idle — skipping hourly fetch" >> "$SCRIPT_DIR/debug-hourly.log"
  exit 0
fi

fetch_usage() {
  # Primary: Anthropic OAuth usage API via Claude Code's keychain token.
  # No browser, no Cloudflare. Token auto-refreshed by Claude Code CLI runs.
  bash "$SCRIPT_DIR/claude-usage-oauth.sh" 2>/dev/null
}

result=$(fetch_usage)
echo "DEBUG: fetch_usage returned: $(echo "$result" | head -c 100)" >> "$SCRIPT_DIR/debug-hourly.log"
# Don't bail on non-zero exit — scraper exits 1 for known recoverable errors (no_org_id, session_expired).
# Only bail if result is empty (genuine crash with no output).
if [ -z "$result" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | ERROR | Claude usage check failed — scraper produced no output (hourly cron)" >> ~/helm-workspace/system/helm-audit.log
  exit 1
fi

# Parse error field
err=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error','') or '')" 2>/dev/null)
# If we couldn't parse the result as JSON at all, then it's a real crash
if [ $? -ne 0 ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | ERROR | Claude usage check failed — scraper output not valid JSON (hourly cron)" >> ~/helm-workspace/system/helm-audit.log
  exit 1
fi

# On any error, retry up to 3 times with 30s delays.
# Transient Cloudflare 403s self-clear quickly — most retries succeed within 90s.
RELOGIN_COOLDOWN_FILE="$SCRIPT_DIR/.last-relogin-from-cron"
retry_count=0
while [ "$err" != "" ] && [ "$err" != "None" ] && [ $retry_count -lt 3 ]; do
  sleep 30
  result=$(fetch_usage)
  err=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error','') or '')" 2>/dev/null)
  retry_count=$((retry_count + 1))
done

if [ "$err" = "session_expired" ] || [ "$err" = "no_org_id" ]; then
  # Session needs refresh — trigger auto-relogin (12h cooldown to avoid loop)
  last_relogin=$(cat "$RELOGIN_COOLDOWN_FILE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if [ $((now - last_relogin)) -gt 43200 ]; then
    echo "$now" > "$RELOGIN_COOLDOWN_FILE"
    bash "$SCRIPT_DIR/claude-auto-relogin.sh" &
  fi
  exit 0
fi

if [ "$err" != "" ] && [ "$err" != "None" ]; then
  # Other error — log once per 3hr to avoid spam
  last_posted=$(cat "$ERROR_STATE_FILE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if [ $((now - last_posted)) -gt 10800 ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | ERROR | Claude usage fetch error: $err (3 retries failed — suppressing for 3hr)" >> ~/helm-workspace/system/helm-audit.log
    echo "$now" > "$ERROR_STATE_FILE"
  fi
  exit 0
fi

# Successful fetch — clear error state
rm -f "$ERROR_STATE_FILE"

# ONBOARD-USAGE-THRESHOLD-001: read user-configured alert threshold from CONFIG.md (default: 80).
# Onboarding saves USAGE_WARNING_THRESHOLD=70|85|95; this script now honours it.
CONFIG_MD="$HOME/helm-workspace/CONFIG.md"
WARN_THRESHOLD=80
if [ -f "$CONFIG_MD" ]; then
  _t=$(grep '^USAGE_WARNING_THRESHOLD:' "$CONFIG_MD" 2>/dev/null | sed 's/[^0-9]//g')
  if [ -n "$_t" ] && [ "$_t" -ge 50 ] && [ "$_t" -le 100 ] 2>/dev/null; then WARN_THRESHOLD="$_t"; fi
fi
WARN_YELLOW=$(( WARN_THRESHOLD - 20 ))

# Parse values
five=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('fiveHourPct'); print(round(v) if v is not None else 'n/a')" 2>/dev/null)
seven=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('sevenDayPct'); print(round(v) if v is not None else 'n/a')" 2>/dev/null)
sonnet=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('sevenDaySonnetPct'); print(round(v) if v is not None else 'n/a')" 2>/dev/null)

# Determine alert levels
five_icon="✅"
sonnet_icon="✅"
seven_icon="✅"

if [ "$five" != "n/a" ] && [ "$five" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then five_icon="🔴"; fi
if [ "$five" != "n/a" ] && [ "$five" -ge "$WARN_YELLOW" ] && [ "$five" -lt "$WARN_THRESHOLD" ] 2>/dev/null; then five_icon="🟡"; fi

if [ "$sonnet" != "n/a" ] && [ "$sonnet" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then sonnet_icon="🔴"; fi
if [ "$sonnet" != "n/a" ] && [ "$sonnet" -ge "$WARN_YELLOW" ] && [ "$sonnet" -lt "$WARN_THRESHOLD" ] 2>/dev/null; then sonnet_icon="🟡"; fi

if [ "$seven" != "n/a" ] && [ "$seven" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then seven_icon="🔴"; fi
if [ "$seven" != "n/a" ] && [ "$seven" -ge "$WARN_YELLOW" ] && [ "$seven" -lt "$WARN_THRESHOLD" ] 2>/dev/null; then seven_icon="🟡"; fi

NOW=$(date -u +"%H:%MZ")
MSG="${five_icon} Session (5hr): **${five}%**  ${sonnet_icon} Sonnet 7-day: **${sonnet}%**  ${seven_icon} Overall 7-day: **${seven}%**  _(${NOW})_"

# Quiet-when-normal: only post hourly status when the alert band changes
# (✅/🟡/🔴 transitions in either direction). Steady state = silence.
# Threshold alerts below still fire independently at 80%.
BAND_STATE_FILE="$SCRIPT_DIR/.last-status-bands"
bands="${five_icon}${sonnet_icon}${seven_icon}"
last_bands=$(cat "$BAND_STATE_FILE" 2>/dev/null || echo "")
if [ "$bands" != "$last_bands" ]; then
  echo "DEBUG: bands changed, calling discord-post.sh" >> "$SCRIPT_DIR/debug-hourly.log"
  "$DISCORD" "$CHANNEL" "$MSG"
  echo "DEBUG: discord-post.sh exited with code $?" >> "$SCRIPT_DIR/debug-hourly.log"
  echo "$bands" > "$BAND_STATE_FILE"
else
  echo "DEBUG: bands unchanged ($bands), skipping post" >> "$SCRIPT_DIR/debug-hourly.log"
fi

# Fire a louder alert to #pap-improvements if Sonnet hits threshold
if [ "$sonnet" != "n/a" ] && [ "$sonnet" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
  "$DISCORD" "{{USER_CHANNEL_HELM_IMPROVEMENTS}}" "🔴 Sonnet 7-day usage at **${sonnet}%** — PAP may hit rate limits soon"
fi

# COMMS-GAP-001: Alert #pap-improvements when 5hr session hits threshold (dedup: once per 3hr)
FIVE_ALERT_STATE="$SCRIPT_DIR/.last-five-alert-posted"
if [ "$five" != "n/a" ] && [ "$five" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
  last_five=$(cat "$FIVE_ALERT_STATE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if [ $((now - last_five)) -gt 10800 ]; then
    "$DISCORD" "{{USER_CHANNEL_HELM_IMPROVEMENTS}}" "🔴 5hr session usage at **${five}%** — approaching rate limit window"
    echo "$now" > "$FIVE_ALERT_STATE"
  fi
fi

# COMMS-GAP-001: Alert #pap-improvements when overall 7-day hits threshold (dedup: once per 3hr)
SEVEN_ALERT_STATE="$SCRIPT_DIR/.last-seven-alert-posted"
if [ "$seven" != "n/a" ] && [ "$seven" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
  last_seven=$(cat "$SEVEN_ALERT_STATE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if [ $((now - last_seven)) -gt 10800 ]; then
    "$DISCORD" "{{USER_CHANNEL_HELM_IMPROVEMENTS}}" "🔴 Overall 7-day usage at **${seven}%** — PAP is running hot"
    echo "$now" > "$SEVEN_ALERT_STATE"
  fi
fi

# Pre-expiry alert: warn 7 days ahead so {{USER_JERRY}} can prepare for manual re-login
PREEXPIRY_STATE="$SCRIPT_DIR/.last-preexpiry-posted"
preexpiry_days=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); w=d.get('preExpiryWarning',{}); print(w.get('days','') if w else '')" 2>/dev/null)
if [ "$preexpiry_days" != "" ] && [ "$preexpiry_days" -le 7 ] 2>/dev/null; then
  last_preexpiry=$(cat "$PREEXPIRY_STATE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if [ $((now - last_preexpiry)) -gt 86400 ]; then
    # Session expiry is handled automatically via Gmail MCP agent — no user action needed.
    # This alert is just a heads-up in case auto-relogin fails.
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | INFO | Claude session expires in ${preexpiry_days} day(s) — auto-relogin will handle this." >> ~/helm-workspace/system/helm-audit.log
    echo "$now" > "$PREEXPIRY_STATE"
  fi
fi
