#!/usr/bin/env bash
# helm-dead-mans-ping.sh — External dead-man's switch.
# Pings Healthchecks.io every 5 min so an external service knows HELM is alive.
# If pings stop (both Mac Mini + VPS down), Healthchecks.io emails {{USER_EMAIL}}.
# This survives simultaneous failure of both machines.
#
# SETUP REQUIRED (one-time):
# 1. Create free account at https://healthchecks.io
# 2. Create a check: "HELM Alive" — period 5 min, grace 10 min, alert to {{USER_EMAIL}}
# 3. Copy the ping URL (e.g. https://hc-ping.com/YOUR-UUID-HERE)
# 4. Save URL to PAP Vault: op item create --vault "PAP Vault" --title "HELM Healthchecks Ping URL" --field label=url value=URL
# 5. On first run, this script reads it from vault automatically.

UUID_FILE="$HOME/helm-workspace/.healthchecks-ping-url"
LOG="$HOME/helm-workspace/logs/dead-mans-ping.log"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$LOG")"

# Load ping URL from cache file or vault
if [[ ! -f "$UUID_FILE" ]]; then
    PING_URL=$(op item get "HELM Healthchecks Ping URL" --vault "PAP Vault" --fields url --reveal 2>/dev/null || echo "")
    if [[ -z "$PING_URL" ]]; then
        echo "[$TIMESTAMP] WARN: Healthchecks ping URL not in vault — dead-man's switch not active. Run setup steps in script header." >> "$LOG"
        exit 0
    fi
    echo "$PING_URL" > "$UUID_FILE"
fi

PING_URL=$(cat "$UUID_FILE")
if curl -s -m 8 "$PING_URL" -o /dev/null 2>/dev/null; then
    echo "[$TIMESTAMP] ping ok" >> "$LOG"
else
    echo "[$TIMESTAMP] WARN: ping failed — network or service issue" >> "$LOG"
fi
