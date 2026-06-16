#!/bin/bash
# HELM Pre-flight Check
# Verifies the system is ready to run HELM.
# Usage: bash preflight-check.sh

set -euo pipefail

PASS=0
FAIL=0
WARN=0

_pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ❌ $1"; echo "     Fix: $2"; FAIL=$((FAIL + 1)); }
_warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HELM Pre-flight Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Check 1: Node.js ──────────────────────────────────────────────────────────
echo "1. Node.js"
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>/dev/null | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [[ "$NODE_MAJOR" -ge 18 ]]; then
    _pass "Node.js $NODE_VER installed"
  else
    _fail "Node.js $NODE_VER is too old (need v18+)" \
          "Run: brew install node  OR  nvm install 20"
  fi
else
  _fail "Node.js not found" \
        "Install from https://nodejs.org — choose LTS version"
fi

# ─── Check 2: Claude Code CLI ──────────────────────────────────────────────────
echo ""
echo "2. Claude Code CLI"
if command -v claude &>/dev/null; then
  CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "installed")
  _pass "Claude Code CLI found ($CLAUDE_VER)"
else
  _fail "Claude Code CLI not installed" \
        "Install from https://claude.ai/code — click 'Install CLI'"
fi

# ─── Check 3: Discord bot token ────────────────────────────────────────────────
echo ""
echo "3. Discord bot token"
ENV_FILE="$HOME/marvin-bot/.env"
if [[ -f "$ENV_FILE" ]]; then
  if grep -q "^DISCORD_BOT_TOKEN=." "$ENV_FILE"; then
    TOKEN_PREFIX=$(grep "^DISCORD_BOT_TOKEN=" "$ENV_FILE" | cut -d= -f2 | cut -c1-6)
    _pass "Token found in .env (starts with '${TOKEN_PREFIX}...')"
  else
    _fail "DISCORD_BOT_TOKEN is empty in .env" \
          "Edit $ENV_FILE and paste your bot token after DISCORD_BOT_TOKEN="
  fi
else
  _fail ".env file not found at $ENV_FILE" \
        "Create it: echo 'DISCORD_BOT_TOKEN=your_token_here' > ~/marvin-bot/.env"
fi

# ─── Check 4: GitHub auth ──────────────────────────────────────────────────────
echo ""
echo "4. GitHub auth (gh CLI)"
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    GH_USER=$(gh api user --jq .login 2>/dev/null || echo "authenticated")
    _pass "GitHub CLI authenticated as $GH_USER"
  else
    _warn "GitHub CLI installed but not authenticated (optional — needed for repo sync)"
  fi
else
  _warn "GitHub CLI (gh) not installed — optional, needed for repo sync"
fi

# ─── Check 5: marvin-bot dependencies ─────────────────────────────────────────
echo ""
echo "5. Bot dependencies (node_modules)"
MARVIN_BOT_DIR="$HOME/marvin-bot"
if [[ -d "$MARVIN_BOT_DIR/node_modules" ]]; then
  _pass "node_modules exists in $MARVIN_BOT_DIR"
else
  _fail "node_modules missing" \
        "Run: cd ~/marvin-bot && npm install"
fi

# ─── Check 6: HELM workspace directory ─────────────────────────────────────────
echo ""
echo "6. HELM workspace"
HELM_DIR="$HOME/helm-workspace"
if [[ -d "$HELM_DIR" ]]; then
  _pass "helm-workspace directory found"
else
  _fail "helm-workspace directory not found at $HELM_DIR" \
        "Run HELM setup first: bash ~/marvin-bot/helm-init.sh"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL + WARN))
echo "  Results: $PASS/$TOTAL passed, $FAIL failed, $WARN warnings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "  Fix the ❌ items above before starting HELM."
  echo ""
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "  Ready to start (with warnings). Optional items skipped."
  echo ""
  exit 0
else
  echo "  All checks passed. HELM is ready to run."
  echo "  Start with: cd ~/marvin-bot && node bot.js"
  echo ""
  exit 0
fi
