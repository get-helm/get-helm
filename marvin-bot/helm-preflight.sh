#!/usr/bin/env bash
# helm-preflight.sh — Check that HELM's dependencies are ready before starting the bot
# Usage: bash helm-preflight.sh
#
# Returns exit 0 if everything is ready.
# Returns exit 1 with plain-English instructions if anything is missing.
# Designed for non-technical users — no stack traces, no jargon.

set -euo pipefail

PASS=0
WARN=0
FAIL=0
MARVIN_BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${HELM_WORKDIR:-${HOME}/helm-workspace}"
ENV_FILE="${MARVIN_BOT_DIR}/.env"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        HELM Pre-Flight Check              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

pass()  { echo "  ✅  $1"; PASS=$((PASS + 1)); }
warn()  { echo "  ⚠️   $1"; WARN=$((WARN + 1)); }
fail()  { echo "  ❌  $1"; FAIL=$((FAIL + 1)); }
info()  { echo "      $1"; }

# ─── 1. Node.js ─────────────────────────────────────────────────────────────
echo "1. Node.js"
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version | tr -d 'v')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ]; then
    pass "Node.js $NODE_VER — ready"
  else
    fail "Node.js $NODE_VER is too old — HELM requires version 18 or higher"
    info "Fix: go to nodejs.org, download the LTS version, and run the installer"
  fi
else
  fail "Node.js not found"
  info "Fix: go to nodejs.org, download the LTS installer, run it, then reopen this window"
fi
echo ""

# ─── 2. npm + node_modules ──────────────────────────────────────────────────
echo "2. Bot dependencies"
if [ -d "${MARVIN_BOT_DIR}/node_modules" ]; then
  pass "node_modules installed"
else
  fail "Bot dependencies not installed"
  info "Fix: run this in your terminal:"
  info "  cd ~/marvin-bot && npm install"
fi
echo ""

# ─── 3. Claude Code ─────────────────────────────────────────────────────────
echo "3. Claude Code"
CLAUDE_PATH="${CLAUDE_PATH:-${HOME}/.local/bin/claude}"
if command -v claude >/dev/null 2>&1 || [ -x "$CLAUDE_PATH" ]; then
  pass "Claude Code found"
else
  fail "Claude Code not found"
  info "Fix: install Claude Code from claude.ai/code, then reopen this window"
fi
echo ""

# ─── 4. .env file ───────────────────────────────────────────────────────────
echo "4. Environment file"
if [ -f "$ENV_FILE" ]; then
  if grep -q "DISCORD_BOT_TOKEN=" "$ENV_FILE" 2>/dev/null; then
    TOKEN_VAL=$(grep "DISCORD_BOT_TOKEN=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -n "$TOKEN_VAL" ] && [ "$TOKEN_VAL" != "your_token_here" ]; then
      pass ".env file found with Discord token set"
    else
      fail ".env file exists but Discord token is empty or placeholder"
      info "Fix: open ~/marvin-bot/.env and set DISCORD_BOT_TOKEN to your bot token"
    fi
  else
    fail ".env file exists but is missing DISCORD_BOT_TOKEN"
    info "Fix: add a line DISCORD_BOT_TOKEN=your_bot_token to ~/marvin-bot/.env"
  fi
else
  fail ".env file not found at ~/marvin-bot/.env"
  info "Fix: run helm-init.sh to create your configuration, or copy .env.template to .env"
fi
echo ""

# ─── 5. Discord token validity ───────────────────────────────────────────────
echo "5. Discord connection"
if [ -f "$ENV_FILE" ]; then
  TOKEN_VAL=$(grep "DISCORD_BOT_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
  if [ -n "$TOKEN_VAL" ] && [ "$TOKEN_VAL" != "your_token_here" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bot ${TOKEN_VAL}" \
      "https://discord.com/api/v10/users/@me" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
      pass "Discord bot token is valid — connected"
    elif [ "$HTTP_STATUS" = "401" ]; then
      fail "Discord bot token is invalid (rejected by Discord)"
      info "Fix: go to discord.com/developers/applications, open your app,"
      info "     click 'Bot', then 'Reset Token', and update ~/marvin-bot/.env"
    elif [ "$HTTP_STATUS" = "000" ]; then
      warn "Could not reach Discord — check your internet connection"
      info "If your connection is fine, Discord may be temporarily down"
    else
      warn "Discord returned an unexpected response (HTTP $HTTP_STATUS)"
    fi
  else
    warn "Skipping Discord connection check — token not set (see step 4)"
  fi
else
  warn "Skipping Discord connection check — .env not found (see step 4)"
fi
echo ""

# ─── 6. Workspace directory ──────────────────────────────────────────────────
echo "6. HELM workspace"
if [ -d "$WORKDIR" ]; then
  REQUIRED_DIRS="system channel-state knowledge product"
  MISSING_DIRS=""
  for d in $REQUIRED_DIRS; do
    [ -d "${WORKDIR}/${d}" ] || MISSING_DIRS="$MISSING_DIRS $d"
  done
  if [ -z "$MISSING_DIRS" ]; then
    pass "Workspace at $WORKDIR — all required directories present"
  else
    warn "Workspace exists but missing directories:$MISSING_DIRS"
    info "Fix: run helm-init.sh to finish workspace setup"
  fi
else
  fail "Workspace directory not found at $WORKDIR"
  info "Fix: run helm-init.sh to create your workspace"
fi
echo ""

# ─── 7. channels.json ────────────────────────────────────────────────────────
echo "7. Channel configuration"
CHANNELS_FILE="${WORKDIR}/channels.json"
if [ -f "$CHANNELS_FILE" ]; then
  if node -e "JSON.parse(require('fs').readFileSync('${CHANNELS_FILE}','utf8'))" 2>/dev/null; then
    CHANNEL_COUNT=$(node -e "const c=JSON.parse(require('fs').readFileSync('${CHANNELS_FILE}','utf8')); console.log(Object.keys(c).length)" 2>/dev/null || echo "0")
    pass "channels.json found — $CHANNEL_COUNT channel(s) configured"
  else
    fail "channels.json is not valid JSON"
    info "Fix: run helm-init.sh to regenerate it, or check the file for typos"
  fi
else
  warn "channels.json not found — bot will use default channel IDs"
  info "This is OK for {{USER_JERRY}}'s own instance, but required for new users"
fi
echo ""

# ─── 8. GitHub CLI (optional) ───────────────────────────────────────────────
echo "8. GitHub CLI (optional)"
if command -v gh >/dev/null 2>&1; then
  pass "GitHub CLI found"
else
  warn "GitHub CLI not installed — some features may not work"
  info "Install at cli.github.com (optional — HELM's core features don't require it)"
fi
echo ""

# ─── Summary ────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════"
echo "  Results: $PASS passed, $WARN warnings, $FAIL failed"
echo ""

if [ $FAIL -gt 0 ]; then
  echo "  HELM is not ready to start — fix the ❌ items above first."
  echo "  If you're stuck, run helm-init.sh for guided setup."
  echo ""
  exit 1
elif [ $WARN -gt 0 ]; then
  echo "  HELM can start, but some optional checks didn't pass."
  echo "  You may hit issues — review the ⚠️ items above."
  echo ""
  exit 0
else
  echo "  Everything looks good — you're ready to start HELM."
  echo "  Run: npm start"
  echo ""
  exit 0
fi
