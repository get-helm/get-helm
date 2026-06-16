#!/bin/bash
# Hourly PM trigger — runs every hour via cron.
# Uses 'schedule' trigger type (not 'cpo-scan') so bot.js idle-skip logic applies:
# if no meaningful events + no proactive work + P-SCAN recent → skip (fast no-op).
# Dedicated 8am/3pm cpo-scan crons stay as the guaranteed full-run path.

TRIGGER_FILE="$HOME/pap-workspace/pm-trigger.json"

# Don't clobber a pending trigger; the watcher consumes the file within ~5s.
for i in 1 2 3; do
  [ ! -f "$TRIGGER_FILE" ] && break
  sleep 5
done

# If still blocked after 15s, skip this run (cpo-scan is still processing)
if [ -f "$TRIGGER_FILE" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] hourly trigger skipped — previous trigger still pending"
  exit 0
fi

printf '{"trigger":"schedule","reason":"hourly check (cron)","ts":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRIGGER_FILE"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] hourly schedule trigger written to pm-trigger.json"
