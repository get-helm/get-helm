#!/bin/bash
# claude-oauth-expiry-warning.sh — Posts pre-expiry warning to #pap-status
# Fired by launchd on June 11 and June 14

DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
NTFY="$HOME/marvin-bot/pap-notify-ntfy.sh"
PAP_STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"
DAYS_UNTIL=$1

"$DISCORD_POST" "$PAP_STATUS_CHANNEL" "⚠️ **Claude OAuth expiry warning** — session expires in ~${DAYS_UNTIL} days (around June 18-20). If nothing breaks before then, no action needed — the auto-relogin flow will handle it. This is a heads-up in case you want to manually refresh early." 2>/dev/null

"$NTFY" "Claude OAuth Expiring Soon" "Session expires in ~${DAYS_UNTIL} days (June 18-20). Auto-relogin is wired. No action needed unless something breaks." 2>/dev/null
