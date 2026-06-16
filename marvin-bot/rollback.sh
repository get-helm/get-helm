#!/bin/bash
# rollback.sh — revert bot.js to a previous git commit
# Usage: bash ~/marvin-bot/rollback.sh
#        bash ~/marvin-bot/rollback.sh <commit-hash>

cd /Users/{{USER_HOME}}/marvin-bot

echo "=== PAP Rollback Tool ==="
echo ""

if [ ! -d ".git" ]; then
  echo "ERROR: No git repo found. Cannot roll back."
  exit 1
fi

echo "Recent commits:"
git log --oneline -10
echo ""

TARGET="$1"
if [ -z "$TARGET" ]; then
  echo "Enter the commit hash to roll back to (or press Ctrl-C to cancel):"
  read -r TARGET
fi

if [ -z "$TARGET" ]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Rolling back bot.js to commit: $TARGET"

# Extract FIRST — verify before killing anything
git show "$TARGET":bot.js > /tmp/bot-rollback.js 2>/dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Could not find bot.js at commit $TARGET"
  exit 1
fi

# Validate the extracted file is runnable JS before touching the live bot
node --check /tmp/bot-rollback.js 2>/dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: Extracted bot.js failed syntax check — aborting rollback"
  exit 1
fi

echo "Extracted and verified bot.js from $TARGET ($(wc -l < /tmp/bot-rollback.js) lines, syntax OK)"

# Now safe to stop the bot
echo "Stopping bot..."
pkill -f "node bot.js" 2>/dev/null
sleep 2

cp /tmp/bot-rollback.js bot.js
echo "bot.js restored to $TARGET"

echo "Restarting bot..."
bash /Users/{{USER_HOME}}/marvin-bot/safe-restart.sh
echo "Done. Check #pap-status to confirm Marvin is back online."
