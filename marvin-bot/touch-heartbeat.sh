#!/usr/bin/env bash
# touch-heartbeat.sh — File-based watchdog heartbeat (replaces Discord noise posts).
#
# Background:
#   bot.js watchdog (LIVENESS-STREAM-001 + Phase 2 checkpoint mtime) already extends
#   the silence window when (a) the spawned claude process writes to stdout, OR
#   (b) the channel-state file mtime is fresh (<3 min).
#
#   Long agents (PM sweep, engineer batch) previously posted ⏳ messages to Discord
#   purely to extend the watchdog. That polluted #helm-audit with internal noise.
#   This script bumps the channel-state mtime instead — same watchdog effect, zero
#   Discord traffic.
#
# Usage: ~/marvin-bot/touch-heartbeat.sh <channel_id> [reason]
#
# Exit codes:
#   0 = heartbeat written
#   1 = channel-state file not found (caller should still continue — watchdog has
#       other liveness signals like stdout activity)

set -u

CHANNEL_ID="${1:-}"
REASON="${2:-internal}"

if [ -z "$CHANNEL_ID" ]; then
  echo "usage: touch-heartbeat.sh <channel_id> [reason]" >&2
  exit 2
fi

STATE_FILE="$HOME/helm-workspace/channel-state/${CHANNEL_ID}.json"

if [ ! -f "$STATE_FILE" ]; then
  # No state file — caller can ignore. Other liveness signals (stdout, CPU) still apply.
  exit 1
fi

# Touch the file to bump mtime. Watchdog Phase 2 (bot.js ~line 1752) reads
# fs.statSync(cpFile).mtimeMs — touch is sufficient and cheaper than rewriting JSON.
touch "$STATE_FILE"

# Optional audit trail (file-only, never Discord) — keeps last 50 heartbeats per channel.
AUDIT_DIR="$HOME/helm-workspace/system"
AUDIT_LOG="$AUDIT_DIR/heartbeat.log"
mkdir -p "$AUDIT_DIR"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $CHANNEL_ID $REASON" >> "$AUDIT_LOG"

# Rotate at 500 lines (cheap, prevents unbounded growth).
LINE_COUNT=$(wc -l < "$AUDIT_LOG" 2>/dev/null | tr -d ' ')
if [ -n "$LINE_COUNT" ] && [ "$LINE_COUNT" -gt 500 ]; then
  tail -n 250 "$AUDIT_LOG" > "$AUDIT_LOG.tmp" && mv "$AUDIT_LOG.tmp" "$AUDIT_LOG"
fi

exit 0
