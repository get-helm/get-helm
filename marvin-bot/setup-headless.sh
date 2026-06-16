#!/bin/bash
# setup-headless.sh — Non-interactive HELM setup, reads from ~/helm-workspace/setup-config.txt
# Called by the Cowork install prompt after collecting all user inputs conversationally.
# Writes CONFIG.md, ABOUT-ME.md, starts the bot, and configures auto-start.
# Exit 0 = success. Exit 1 = fatal error (caller narrates in plain English).

set -euo pipefail

WORKSPACE=~/helm-workspace
CONFIG_TMP="$WORKSPACE/setup-config.txt"
CONFIG_OUT="$WORKSPACE/CONFIG.md"
ABOUT_ME="$WORKSPACE/ABOUT-ME.md"
HELM_DIR="$HOME/helm"
MARVIN_BOT="$HELM_DIR/marvin-bot/bot.js"

log() { echo "[setup-headless] $1" >&2; }

# Read value from setup-config.txt
get_val() {
  local key="$1"
  local default="${2:-}"
  grep -m1 "^$key=" "$CONFIG_TMP" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "$default"
}

if [[ ! -f "$CONFIG_TMP" ]]; then
  log "setup-config.txt not found — nothing to configure"
  exit 1
fi

AGENT_NAME=$(get_val "AGENT_NAME" "HELM")
USER_NAME=$(get_val "USER_PREFERRED_NAME" "")
DISCORD_SERVER_ID=$(get_val "DISCORD_SERVER_ID" "")
DISCORD_OWNER_ID=$(get_val "DISCORD_OWNER_ID" "")
DISCORD_TOKEN=$(get_val "DISCORD_BOT_TOKEN" "")
GITHUB_USERNAME=$(get_val "GITHUB_USERNAME" "")
GITHUB_TOKEN=$(get_val "GITHUB_TOKEN" "")
TIMEZONE=$(get_val "TIMEZONE" "")
# Leave TIMEZONE unset until Stage-2 timezone question — date +%Z returns
# abbreviations (PST/EST) which break Intl.DateTimeFormat; IANA name needed
if [[ -z "$TIMEZONE" ]]; then
  TIMEZONE="America/Los_Angeles"
fi

log "Configuring HELM for: $AGENT_NAME / $USER_NAME"

# Write ABOUT-ME.md
cat > "$ABOUT_ME" << EOF
# About Me
AGENT_NAME=$AGENT_NAME
USER_PREFERRED_NAME=$USER_NAME
TIMEZONE=$TIMEZONE
DISCORD_SERVER_ID=$DISCORD_SERVER_ID

TOOLS_I_USE_DAILY=Discord (primary HELM interface)
TECH_LEVEL=Non-technical — translate everything to plain English
EOF

# Write CONFIG.md (merge with template if exists)
TEMPLATE="$WORKSPACE/CONFIG.md.template"
if [[ -f "$TEMPLATE" ]]; then
  sed \
    -e "s/{{AGENT_NAME}}/$AGENT_NAME/g" \
    -e "s/{{USER_JERRY}}/$USER_NAME/g" \
    -e "s/{{TIMEZONE}}/$TIMEZONE/g" \
    -e "s/{{DISCORD_SERVER_ID}}/$DISCORD_SERVER_ID/g" \
    -e "s/{{GITHUB_USERNAME}}/$GITHUB_USERNAME/g" \
    -e "s/ONBOARDING_COMPLETED: false/ONBOARDING_COMPLETED: true/g" \
    "$TEMPLATE" > "$CONFIG_OUT"
else
  cat > "$CONFIG_OUT" << EOF
# HELM Configuration

AGENT_NAME: $AGENT_NAME
USER_PREFERRED_NAME: $USER_NAME
TIMEZONE: $TIMEZONE
ONBOARDING_COMPLETED: true
DATE_FORMAT: MM/DD/YYYY
TIME_FORMAT: 12-hour
WEEK_STARTS_ON: Sunday
COLOR_PRIMARY: #4A7C59
COLOR_ACCENT_1: #7C3AED
COLOR_ACCENT_2: #D97706
DISPLAY_MODE: dark
IMPROVEMENTS_FREQUENCY: weekly
PROACTIVE_OUTREACH: sometimes
USAGE_WARNING_THRESHOLD: 85
DISCORD_SERVER_ID: $DISCORD_SERVER_ID
GITHUB_USERNAME: $GITHUB_USERNAME
EOF
fi

MARVIN_ENV="$HELM_DIR/marvin-bot/.env"
touch "$MARVIN_ENV" 2>/dev/null || true
chmod 600 "$MARVIN_ENV" 2>/dev/null || true

write_env() {
  local key="$1" val="$2"
  if [[ -n "$val" ]] && ! grep -q "^${key}=" "$MARVIN_ENV" 2>/dev/null; then
    echo "${key}=${val}" >> "$MARVIN_ENV"
    log "Wrote $key to .env"
  fi
}

write_env "DISCORD_BOT_TOKEN" "$DISCORD_TOKEN"
write_env "DISCORD_OWNER_ID" "$DISCORD_OWNER_ID"
write_env "DISCORD_GUILD_ID" "$DISCORD_SERVER_ID"
write_env "GITHUB_PAT" "$GITHUB_TOKEN"

# Write QMD install in background (2GB model download — non-blocking)
QMD_INSTALL="$HELM_DIR/marvin-bot/qmd-install.sh"
if [[ -f "$QMD_INSTALL" ]]; then
  nohup bash "$QMD_INSTALL" /tmp/qmd-install.log >/dev/null 2>&1 &
  log "QMD install started in background (PID $!)"
fi

# Clean up temp config (no longer needed)
rm -f "$CONFIG_TMP"

# Configure auto-start
PLATFORM=$(uname -s)
if [[ "$PLATFORM" == "Darwin" ]]; then
  PLIST_PATH="$HOME/Library/LaunchAgents/com.helm.bot.plist"
  if [[ ! -f "$PLIST_PATH" ]]; then
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.helm.bot</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(which node)</string>
    <string>$HELM_DIR/marvin-bot/bot.js</string>
  </array>
  <key>WorkingDirectory</key><string>$HELM_DIR/marvin-bot</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$WORKSPACE/system/marvin.log</string>
  <key>StandardErrorPath</key><string>$WORKSPACE/system/marvin.log</string>
</dict>
</plist>
EOF
    launchctl load "$PLIST_PATH" 2>/dev/null || true
    log "Auto-start configured (launchd)"
  fi
fi

log "Setup complete — AGENT_NAME=$AGENT_NAME USER=$USER_NAME"
exit 0
