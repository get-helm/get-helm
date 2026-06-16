#!/usr/bin/env bash
# claude-usage-oauth.sh — Fetch Claude subscription usage via Claude Code's OAuth token.
# No browser, no Cloudflare, no magic links. Token lives in macOS Keychain and is
# auto-refreshed by Claude Code itself every time the CLI runs (bot.js runs it constantly).
# Output: JSON matching claude-scraper.py shape: fiveHourPct, sevenDayPct, sevenDaySonnetPct
# On failure: {"error": "<reason>"}

set -o pipefail

# Token cache. The macOS `security` command intermittently returns empty (a known,
# probabilistic Keychain quirk tied to process lifecycle). We retry a few times, and
# fall back to a cached copy of the last good access token when the Keychain comes up
# empty. Only the short-lived accessToken is cached (never the refreshToken) to keep
# the leak surface minimal; if it's stale the API returns 401 and we report transient.
CACHE_DIR="$HOME/.cache/claude-usage"
CACHE_FILE="$CACHE_DIR/oauth-token"

read_keychain_token() {
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null
}

TOKEN=""
for attempt in 1 2 3; do
  TOKEN=$(read_keychain_token)
  [ -n "$TOKEN" ] && break
  sleep 0.5
done

if [ -n "$TOKEN" ]; then
  # Good read — refresh the cache atomically with restrictive perms.
  mkdir -p "$CACHE_DIR" && chmod 700 "$CACHE_DIR" 2>/dev/null
  ( umask 177; printf '%s' "$TOKEN" > "$CACHE_FILE.tmp" ) && mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
else
  # Keychain came up empty after retries — fall back to last good cached token.
  if [ -f "$CACHE_FILE" ]; then
    TOKEN=$(cat "$CACHE_FILE" 2>/dev/null)
  fi
fi

if [ -z "$TOKEN" ]; then
  echo '{"error": "no_oauth_token"}'
  exit 1
fi

RESP=$(curl -s --max-time 30 -w "\n%{http_code}" "https://api.anthropic.com/api/oauth/usage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  # OAuth token expired. Claude Code refreshes it on next CLI run — almost always
  # fresh within the hour. Report as transient; do NOT trigger any login flow.
  echo '{"error": "oauth_token_stale"}'
  exit 1
fi

if [ "$HTTP_CODE" != "200" ]; then
  echo "{\"error\": \"http_${HTTP_CODE}\"}"
  exit 1
fi

echo "$BODY" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(json.dumps({'error': 'bad_json'})); sys.exit(1)

def pct(key):
    v = d.get(key) or {}
    u = v.get('utilization')
    return round(u, 1) if u is not None else None

def resets(key):
    v = d.get(key) or {}
    return v.get('resets_at')

extra = d.get('extra_usage') or {}
out = {
    'fiveHourPct': pct('five_hour'),
    'sevenDayPct': pct('seven_day'),
    'sevenDaySonnetPct': pct('seven_day_sonnet'),
    'sevenDayOpusPct': pct('seven_day_opus'),
    'fiveHourResetsAt': resets('five_hour'),
    'sevenDayResetsAt': resets('seven_day'),
    'extraUsageEnabled': extra.get('is_enabled'),
    'extraUsageUsedCredits': extra.get('used_credits'),
    'extraUsageMonthlyLimit': extra.get('monthly_limit'),
    'source': 'oauth',
}
print(json.dumps(out))
" || { echo '{"error": "parse_failed"}'; exit 1; }
