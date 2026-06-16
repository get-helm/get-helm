#!/usr/bin/env bash
# Sends a heartbeat to VPS health monitor so it knows bot.js is alive.

LOG="$HOME/marvin-bot/heartbeat.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Check Tailscale before attempting — if it's down, the POST will silently fail
if ! /usr/local/bin/tailscale status &>/dev/null 2>&1; then
  echo "[$TS] WARN: Tailscale daemon not responding — heartbeat POST will likely fail" >> "$LOG"
fi

if curl -s -X POST http://{{USER_VPS_TAILSCALE_IP}}:9876/heartbeat -m 10 >> "$LOG" 2>&1; then
  echo " [$TS] heartbeat sent" >> "$LOG"
else
  echo " [$TS] WARN: heartbeat POST failed (Tailscale down or VPS unreachable)" >> "$LOG"
fi
