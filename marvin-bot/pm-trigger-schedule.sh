#!/bin/bash
# Writes pm-trigger.json for the 15-min scheduled PM sweep.
# Called by com.pap.pm.sweep launchd job.
LOG=/Users/{{USER_HOME}}/marvin-bot/pm-sweep.log
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pm-trigger-schedule.sh fired" >> "$LOG"

# Pre-filter: skip idle spawns when no new user activity and engineer work is flowing
SHOULD_SPAWN=$("$HOME/marvin-bot/pm-should-spawn.sh" 2>/dev/null)
if [ "$SHOULD_SPAWN" = "SKIP" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pm-should-spawn.sh → SKIP (no new user activity, queue active)" >> "$LOG"
    exit 0
fi

echo "{\"trigger\":\"schedule\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /Users/{{USER_HOME}}/helm-workspace/pm-trigger.json
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pm-trigger.json written (SPAWN approved)" >> "$LOG"
