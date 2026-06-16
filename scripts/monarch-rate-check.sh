#!/bin/bash
# Check Monarch login rate limit before allowing any SSH run.
# Usage: source this script or run it; exits non-zero if blocked.
#
# Lock file tracks last run time on Mac Mini side.
# VPS scripts have their own lock file as a second layer.

LOCK_FILE="/Users/{{USER_HOME}}/pap-workspace/scripts/.monarch-last-login"
COOLDOWN=1800  # 30 minutes in seconds

if [ -f "$LOCK_FILE" ]; then
    LAST=$(cat "$LOCK_FILE")
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST ))
    if [ "$ELAPSED" -lt "$COOLDOWN" ]; then
        REMAINING=$(( (COOLDOWN - ELAPSED) / 60 ))
        echo "BLOCKED: Monarch login cooldown active. Last attempt: $(date -r $LAST). Wait ${REMAINING} more min."
        exit 1
    fi
fi

# Record this attempt
date +%s > "$LOCK_FILE"
echo "OK: Login attempt logged at $(date). Next allowed in 30 min."
exit 0
