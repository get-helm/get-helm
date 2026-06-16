#!/usr/bin/env bash
# helm-healthcheck-ping.sh — Sends heartbeat to Healthchecks.io every 5 min.
# If Mac Mini goes dark, Healthchecks.io alerts after 10 min via email.
# This is the external dead-man's-switch — works even when both local machines fail.
# Cron: */5 * * * *

PING_URL="https://hc-ping.com/355b4bf1-9601-4288-99a4-bb717e52596a"
LOG="$HOME/helm-workspace/logs/healthcheck-ping.log"

mkdir -p "$(dirname "$LOG")"

# Only ping if bot is actually running
if pgrep -f "bot\.js" > /dev/null 2>&1; then
    HTTP=$(curl -fsS --retry 3 --max-time 10 "${PING_URL}" -o /dev/null -w "%{http_code}" 2>/dev/null)
    if [[ "$HTTP" == "200" ]]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] OK" >> "$LOG"
    else
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARN: ping returned HTTP $HTTP" >> "$LOG"
    fi
else
    # Bot is down — do NOT send /fail; silence alone triggers HC.io outage detection
    # Explicit /fail caused immediate DOWN+UP emails on brief restarts
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SKIP: bot.js not running — withholding ping (HC.io detects silence)" >> "$LOG"
fi
