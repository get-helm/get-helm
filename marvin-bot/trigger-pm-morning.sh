#!/bin/bash
# CPO scan trigger — 8am PT (15:00 UTC) and 3pm PT (22:00 UTC) via cron.
# Rewritten 2026-06-12: previously posted instructions to #helm-improvements as a
# bot-authored Discord message, which bot.js never routes to an agent — daily noise,
# zero executions. Now writes pm-trigger.json, the proven spawn path (bot.js watcher).
# Trigger type "cpo-scan" bypasses the pre-spawn idle-skip (only "schedule" is skippable),
# so the work-finding scan runs even when queues/boards are empty — which is exactly
# when it is needed most.
# Rollback: git checkout this file; remove the cpo-scan-afternoon cron line.

TRIGGER_FILE="$HOME/pap-workspace/pm-trigger.json"

# Don't clobber a pending trigger; the watcher consumes the file within ~5s.
for i in 1 2 3; do
  [ ! -f "$TRIGGER_FILE" ] && break
  sleep 5
done

printf '{"trigger":"cpo-scan","reason":"scheduled work-finding scan (8am/3pm PT cron)","ts":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRIGGER_FILE"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] cpo-scan trigger written to pm-trigger.json"
