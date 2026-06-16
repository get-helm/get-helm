#!/bin/bash
# pm-log-write.sh — Append a timestamped entry to the PM log
# Usage: pm-log-write.sh "CATEGORY" "message"
PM_LOG="/Users/{{USER_HOME}}/helm-workspace/pm-log.md"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$TS] [$1] $2" >> "$PM_LOG"
