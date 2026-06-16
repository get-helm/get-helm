#!/usr/bin/env bash
# schedule-next-renewal.sh — After a successful relogin, schedule the next renewal cycle.
# Assumes new session expires 30 days from now.
# Creates launchd plists for: 7-day warning, 5-day warning, and proactive refresh at day 28.
# Old plists for prior cycle are unloaded and removed first.

LOG="/Users/{{USER_HOME}}/helm-workspace/scripts/usage/auto-relogin.log"
PLIST_DIR="$HOME/Library/LaunchAgents"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
PAP_STATUS_CHANNEL="{{USER_CHANNEL_HELM_STATUS}}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [schedule-next-renewal] $*" >> "$LOG"; }

# Calculate renewal dates
NEXT_EXPIRY_EPOCH=$(python3 -c "import time; print(int(time.time()) + 30*86400)")
WARN7_EPOCH=$(python3 -c "import time; print(int(time.time()) + 23*86400)")   # 7 days before expiry
WARN5_EPOCH=$(python3 -c "import time; print(int(time.time()) + 25*86400)")   # 5 days before expiry
REFRESH_EPOCH=$(python3 -c "import time; print(int(time.time()) + 28*86400)") # 2 days before expiry

WARN7_DATE=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($WARN7_EPOCH).strftime('%Y-%m-%d'))")
WARN5_DATE=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($WARN5_EPOCH).strftime('%Y-%m-%d'))")
REFRESH_DATE=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($REFRESH_EPOCH).strftime('%Y-%m-%d'))")
EXPIRY_DATE=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($NEXT_EXPIRY_EPOCH).strftime('%Y-%m-%d'))")

log "New session expires ~$EXPIRY_DATE — scheduling: warn7=$WARN7_DATE, warn5=$WARN5_DATE, proactive-refresh=$REFRESH_DATE"

# Helper: extract year/month/day from YYYY-MM-DD
year()  { echo "${1%%-*}"; }
month() { echo "${1#*-}" | cut -d- -f1; }
day()   { echo "${1##*-}"; }

# Remove old renewal plists (keep june ones for this cycle if still in the future)
for label in com.pap.claude-renewal-warn7 com.pap.claude-renewal-warn5 com.pap.claude-renewal-refresh; do
  PLIST="$PLIST_DIR/${label}.plist"
  if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    log "Removed old plist: $label"
  fi
done

# Create 7-day warning plist
cat > "$PLIST_DIR/com.pap.claude-renewal-warn7.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pap.claude-renewal-warn7</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/{{USER_HOME}}/marvin-bot/claude-oauth-expiry-warning.sh</string>
    <string>7</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Year</key><integer>$(year $WARN7_DATE)</integer>
    <key>Month</key><integer>$(month $WARN7_DATE)</integer>
    <key>Day</key><integer>$(day $WARN7_DATE)</integer>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/tmp/pap-oauth-warning.log</string>
  <key>StandardErrorPath</key><string>/tmp/pap-oauth-warning.log</string>
</dict>
</plist>
PLIST

# Create 5-day warning plist
cat > "$PLIST_DIR/com.pap.claude-renewal-warn5.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pap.claude-renewal-warn5</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/{{USER_HOME}}/marvin-bot/claude-oauth-expiry-warning.sh</string>
    <string>5</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Year</key><integer>$(year $WARN5_DATE)</integer>
    <key>Month</key><integer>$(month $WARN5_DATE)</integer>
    <key>Day</key><integer>$(day $WARN5_DATE)</integer>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/tmp/pap-oauth-warning.log</string>
  <key>StandardErrorPath</key><string>/tmp/pap-oauth-warning.log</string>
</dict>
</plist>
PLIST

# Create proactive-refresh plist (runs session monitor at day 28, 2 days before expiry)
cat > "$PLIST_DIR/com.pap.claude-renewal-refresh.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pap.claude-renewal-refresh</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/{{USER_HOME}}/marvin-bot/claude-session-monitor.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Year</key><integer>$(year $REFRESH_DATE)</integer>
    <key>Month</key><integer>$(month $REFRESH_DATE)</integer>
    <key>Day</key><integer>$(day $REFRESH_DATE)</integer>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/tmp/pap-oauth-refresh.log</string>
  <key>StandardErrorPath</key><string>/tmp/pap-oauth-refresh.log</string>
</dict>
</plist>
PLIST

# Load all three new plists
for label in com.pap.claude-renewal-warn7 com.pap.claude-renewal-warn5 com.pap.claude-renewal-refresh; do
  PLIST="$PLIST_DIR/${label}.plist"
  if launchctl load "$PLIST" 2>/dev/null; then
    log "Loaded $label"
  else
    log "WARN: Failed to load $label (may already be loaded or date is in the past)"
  fi
done

log "Renewal schedule set: warn $WARN7_DATE / $WARN5_DATE, proactive refresh $REFRESH_DATE, expiry ~$EXPIRY_DATE"

# Post confirmation to pap-status
"$DISCORD_POST" "$PAP_STATUS_CHANNEL" "✅ Session renewed — next cycle scheduled: warnings on $WARN7_DATE and $WARN5_DATE, proactive refresh on $REFRESH_DATE, expected expiry ~$EXPIRY_DATE." 2>/dev/null
