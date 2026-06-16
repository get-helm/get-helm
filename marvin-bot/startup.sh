#!/bin/sh
# startup.sh — launchd entry point for bot.js.
# Fires helm-back-online check in background, then starts bot.js.
cd /Users/{{USER_HOME}}/marvin-bot
export $(cat .env)
bash /Users/{{USER_HOME}}/marvin-bot/helm-back-online.sh &
exec /opt/homebrew/bin/node bot.js
