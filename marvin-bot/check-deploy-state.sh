#!/usr/bin/env bash
# check-deploy-state.sh — Agents call this before claiming "needs restart"
# If bot started AFTER the last commit, the fix is already deployed.
# Usage: bash ~/marvin-bot/check-deploy-state.sh [optional-commit-hash]
# Output: DEPLOYED | NOT_DEPLOYED | UNKNOWN (with explanation)
# Exit code: 0=deployed, 1=not-deployed, 2=unknown

set -euo pipefail

BOT_START_FILE="$HOME/helm-workspace/bot-start.txt"
MARVIN_BOT_DIR="$HOME/marvin-bot"

# Read bot startup time
if [[ ! -f "$BOT_START_FILE" ]]; then
  echo "UNKNOWN: bot-start.txt not found at $BOT_START_FILE — bot may not have run yet"
  exit 2
fi

BOT_START_RAW=$(cat "$BOT_START_FILE" 2>/dev/null | tr -d '[:space:]')
if [[ -z "$BOT_START_RAW" ]]; then
  echo "UNKNOWN: bot-start.txt is empty"
  exit 2
fi

BOT_START_EPOCH=$(python3 -c "
import sys, datetime
raw = sys.argv[1]
try:
    dt = datetime.datetime.fromisoformat(raw.replace('Z', '+00:00'))
    print(int(dt.timestamp()))
except Exception:
    sys.exit(1)
" "$BOT_START_RAW" 2>/dev/null || echo "")
if [[ -z "$BOT_START_EPOCH" ]]; then
  echo "UNKNOWN: could not parse bot start time: $BOT_START_RAW"
  exit 2
fi

# Get commit timestamp (specific hash or latest)
COMMIT_HASH="${1:-HEAD}"
COMMIT_TS=$(git -C "$MARVIN_BOT_DIR" log -1 --format="%ci" "$COMMIT_HASH" 2>/dev/null || echo "")
if [[ -z "$COMMIT_TS" ]]; then
  echo "UNKNOWN: could not get commit timestamp for $COMMIT_HASH in $MARVIN_BOT_DIR"
  exit 2
fi

COMMIT_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$COMMIT_TS" "+%s" 2>/dev/null || date -d "$COMMIT_TS" "+%s" 2>/dev/null || echo "")
if [[ -z "$COMMIT_EPOCH" ]]; then
  echo "UNKNOWN: could not parse commit timestamp: $COMMIT_TS"
  exit 2
fi

# Compare
COMMIT_ISO=$(git -C "$MARVIN_BOT_DIR" log -1 --format="%cI" "$COMMIT_HASH" 2>/dev/null || echo "$COMMIT_TS")
BOT_START_ISO="$BOT_START_RAW"

if (( BOT_START_EPOCH > COMMIT_EPOCH )); then
  echo "DEPLOYED: bot started ${BOT_START_ISO} which is AFTER last commit ${COMMIT_ISO} — fix is already live, no restart needed"
  exit 0
else
  DIFF=$(( COMMIT_EPOCH - BOT_START_EPOCH ))
  DIFF_MIN=$(( DIFF / 60 ))
  echo "NOT_DEPLOYED: bot started ${BOT_START_ISO} which is ${DIFF_MIN}m BEFORE commit ${COMMIT_ISO} — restart required to activate this change"
  exit 1
fi
