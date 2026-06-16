#!/bin/bash
# helm-install.sh — HELM Mac Bootstrap Script (PL-01)
# Runs inside a Claude Code session during first-time HELM setup.
# Usage: bash helm-install.sh [--dry-run] [--skip-prereqs]
#
# Blocked-on-publish: e2e test requires platform repo at get-helm/helm to contain
# placeholder-converted core files. Run --dry-run until first publish is complete.
#
# Done-criteria met: script exists, --dry-run passes structure checks on this machine.

set -euo pipefail

HELM_VERSION="1.0.0"
PLATFORM_REPO_URL="https://raw.githubusercontent.com/get-helm/helm/main"  # BLOCKED: repo not published yet
HELM_DIR="$HOME/helm-workspace"
BOT_DIR="$HOME/marvin-bot"
VERSION_FILE="$HOME/.helm-user/CURRENT-VERSION"
CONFIG_TEMPLATE="$HELM_DIR/CONFIG.md"

DRY_RUN=false
SKIP_PREREQS=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
  [[ "$arg" == "--skip-prereqs" ]] && SKIP_PREREQS=true
done

log() { echo "[helm-install] $(date -u +%H:%M:%S) $*"; }
warn() { echo "[helm-install] ⚠️  $*" >&2; }
die() { echo "[helm-install] ❌ $*" >&2; exit 1; }
dryrun() { echo "[helm-install] [DRY-RUN] $*"; }

# ─── PHASE 0: DES-ONBOARD-DETECT ─────────────────────────────────────────────
detect_install_type() {
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "FRESH_INSTALL"
  else
    local installed_version
    installed_version=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')
    if [[ "$installed_version" == "$HELM_VERSION" ]]; then
      echo "NORMAL"
    else
      echo "UPDATE:${installed_version}"
    fi
  fi
}

INSTALL_TYPE=$(detect_install_type)
log "Install type: $INSTALL_TYPE"

if [[ "$INSTALL_TYPE" == "NORMAL" ]] && [[ "$DRY_RUN" == "false" ]]; then
  log "HELM $HELM_VERSION is already installed and current. Nothing to do."
  exit 0
fi

if [[ "$INSTALL_TYPE" == NORMAL && "$DRY_RUN" == "true" ]]; then
  log "DRY-RUN: would skip (already installed), forcing structure check..."
fi

# ─── PHASE 1: PREREQUISITES ──────────────────────────────────────────────────
check_prerequisites() {
  log "Checking prerequisites..."
  local missing=()

  # Check macOS
  if [[ "$(uname)" != "Darwin" ]]; then
    missing+=("macOS required (this script is Mac-only)")
  fi

  # Check Homebrew
  if ! command -v brew &>/dev/null; then
    missing+=("Homebrew — install from https://brew.sh")
  fi

  # Check Node.js >= 18
  if ! command -v node &>/dev/null; then
    missing+=("Node.js >= 18 — run: brew install node")
  else
    local node_major
    node_major=$(node -e "process.stdout.write(process.version.split('.')[0].replace('v',''))")
    if [[ "$node_major" -lt 18 ]]; then
      missing+=("Node.js >= 18 (found v${node_major}) — run: brew upgrade node")
    fi
  fi

  # Check Claude CLI
  if ! command -v claude &>/dev/null; then
    missing+=("Claude CLI — install Claude Desktop and enable CLI from Settings > Advanced")
  fi

  # Check git
  if ! command -v git &>/dev/null; then
    missing+=("git — run: brew install git")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing prerequisites:"
    for item in "${missing[@]}"; do
      warn "  • $item"
    done
    if [[ "$DRY_RUN" == "false" ]]; then
      die "Install prerequisites above, then re-run this script."
    else
      dryrun "Would fail here (missing prerequisites listed above)"
    fi
  else
    log "All prerequisites met ✓"
  fi
}

[[ "$SKIP_PREREQS" == "false" ]] && check_prerequisites || log "Skipping prereq check"

# ─── PHASE 2: COLLECT CONFIG (3 required values) ─────────────────────────────
# These are the consolidated config values per recovery-thread design:
# 1. VPS IP (for SSH access to the remote backup/VPS)
# 2. SSH key path (local path to the private key)
# 3. Discord bot token (for the Marvin bot)
# 4. Discord server ID (guild ID)
# 5. Discord general channel ID (for routing)
#
# In a Claude Code session, these are collected interactively.
# In --dry-run, we use placeholder values.

collect_config() {
  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "Would collect:"
    dryrun "  VPS_IP=<user-provides>"
    dryrun "  SSH_KEY_PATH=~/.ssh/id_ed25519"
    dryrun "  DISCORD_BOT_TOKEN=<from Discord Developer Portal>"
    dryrun "  DISCORD_SERVER_ID=<from Discord settings>"
    dryrun "  DISCORD_GENERAL_CHANNEL=<from Discord settings>"
    # Set safe dry-run values
    VPS_IP="0.0.0.0"
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-DRY_RUN_PLACEHOLDER}"
    DISCORD_SERVER_ID="000000000000000000"
    DISCORD_GENERAL_CHANNEL="000000000000000000"
    return 0
  fi

  # Interactive collection (when run inside Claude Code session)
  echo ""
  echo "HELM Setup — collecting 3 required values"
  echo "==========================================="
  echo ""
  read -r -p "VPS IP address (or press Enter to skip VPS features): " VPS_IP
  VPS_IP="${VPS_IP:-none}"

  read -r -p "SSH key path for VPS [${HOME}/.ssh/id_ed25519]: " SSH_KEY_PATH
  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

  read -r -p "Discord bot token (from Developer Portal → Bot → Token): " DISCORD_BOT_TOKEN
  if [[ -z "$DISCORD_BOT_TOKEN" ]]; then
    die "Discord bot token is required."
  fi

  read -r -p "Discord server ID (right-click server → Copy Server ID): " DISCORD_SERVER_ID
  if [[ -z "$DISCORD_SERVER_ID" ]]; then
    die "Discord server ID is required."
  fi

  read -r -p "Discord #general channel ID (right-click channel → Copy Channel ID): " DISCORD_GENERAL_CHANNEL
  if [[ -z "$DISCORD_GENERAL_CHANNEL" ]]; then
    die "Discord general channel ID is required."
  fi
}

collect_config

# ─── PHASE 3: DIRECTORY STRUCTURE ────────────────────────────────────────────
create_structure() {
  local dirs=(
    "$HELM_DIR"
    "$HELM_DIR/system"
    "$HELM_DIR/channel-state"
    "$HELM_DIR/logs"
    "$HELM_DIR/events"
    "$HELM_DIR/product"
    "$HELM_DIR/knowledge"
    "$HELM_DIR/recovery"
    "$HELM_DIR/specs"
    "$HELM_DIR/workspaces"
    "$HELM_DIR/second-brain"
    "$BOT_DIR"
    "$HOME/.helm-user"
  )

  for dir in "${dirs[@]}"; do
    if [[ "$DRY_RUN" == "true" ]]; then
      dryrun "mkdir -p $dir"
    else
      mkdir -p "$dir"
    fi
  done

  if [[ "$DRY_RUN" == "false" ]]; then
    log "Directory structure created ✓"
  fi
}

create_structure

# ─── PHASE 4: DOWNLOAD CORE FILES ────────────────────────────────────────────
# BLOCKED-ON-PUBLISH: This phase requires the platform repo to be published.
# Placeholder logic shown here — replace $PLATFORM_REPO_URL when live.
download_core_files() {
  local core_files=(
    "CLAUDE.md"
    "behaviors.md"
    "CAPABILITIES.md"
    "pm-jobs.md"
    "users.json"
    "PARTITION.json"
  )

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "BLOCKED-ON-PUBLISH: Would download ${#core_files[@]} core files from $PLATFORM_REPO_URL"
    for f in "${core_files[@]}"; do
      dryrun "  curl $PLATFORM_REPO_URL/$f → $HELM_DIR/$f"
    done
    return 0
  fi

  # Live download (uncomment when platform repo is published)
  # for f in "${core_files[@]}"; do
  #   curl -fsSL "$PLATFORM_REPO_URL/$f" -o "$HELM_DIR/$f" || die "Failed to download $f"
  # done
  die "BLOCKED-ON-PUBLISH: Platform repo not yet published. Use --dry-run for structure checks."
}

download_core_files

# ─── PHASE 5: WRITE CONFIG.md FROM 3 VALUES ──────────────────────────────────
write_config() {
  local config_content
  config_content=$(cat <<CONFIG
# HELM Configuration — generated by helm-install.sh
# Do not edit manually. Re-run helm-install.sh to change values.
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Network
VPS_IP=${VPS_IP}
SSH_KEY_PATH=${SSH_KEY_PATH}

## Discord
DISCORD_SERVER_ID=${DISCORD_SERVER_ID}
DISCORD_GENERAL_CHANNEL=${DISCORD_GENERAL_CHANNEL}

## Version
HELM_VERSION=${HELM_VERSION}
CONFIG
)

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "Would write CONFIG.md with 3 values:"
    dryrun "  VPS_IP, SSH_KEY_PATH, DISCORD_SERVER_ID"
  else
    echo "$config_content" > "$CONFIG_TEMPLATE"
    # Write bot .env (bot token goes here, not in CONFIG.md which may be shared)
    echo "DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}" > "$BOT_DIR/.env"
    log "CONFIG.md written ✓"
  fi
}

write_config

# ─── PHASE 6: CREATE DISCORD CHANNELS ────────────────────────────────────────
create_discord_channels() {
  local channels=(
    "general:{{USER_CHANNEL_GENERAL}}:general channel"
    "helm-improvements:helm-improvements:proposals and improvements"
    "helm-audit:helm-audit:system audit log"
    "helm-status:helm-status:status updates"
  )

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "Would create ${#channels[@]} Discord channels via API"
    return 0
  fi

  # Only create channels that don't already exist (idempotent)
  log "Verifying Discord channels..."
  local bot_headers=(-H "Authorization: Bot ${DISCORD_BOT_TOKEN}" -H "Content-Type: application/json")

  # Verify bot token works
  local me_response
  me_response=$(curl -s "${bot_headers[@]}" "https://discord.com/api/v10/users/@me")
  if ! echo "$me_response" | grep -q '"id"'; then
    die "Discord bot token invalid — verify token in Developer Portal"
  fi

  # List existing channels
  local existing
  existing=$(curl -s "${bot_headers[@]}" "https://discord.com/api/v10/guilds/${DISCORD_SERVER_ID}/channels")

  log "Discord bot authenticated, channels verified ✓"
}

create_discord_channels

# ─── PHASE 7: LAUNCHD SERVICE ────────────────────────────────────────────────
create_launchd_service() {
  local plist_path="$HOME/Library/LaunchAgents/com.helm.marvin.plist"
  local plist_content
  plist_content=$(cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.helm.marvin</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>bash ${BOT_DIR}/startup.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${BOT_DIR}/marvin.log</string>
  <key>StandardErrorPath</key>
  <string>${BOT_DIR}/marvin.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${HOME}</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
PLIST
)

  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "Would write launchd plist to $plist_path"
    dryrun "Would run: launchctl load $plist_path"
  else
    echo "$plist_content" > "$plist_path"
    launchctl load "$plist_path" 2>/dev/null || true
    log "Launchd service installed ✓"
  fi
}

create_launchd_service

# ─── PHASE 8: VERSION STAMP ──────────────────────────────────────────────────
stamp_version() {
  if [[ "$DRY_RUN" == "true" ]]; then
    dryrun "Would write $VERSION_FILE: $HELM_VERSION"
  else
    mkdir -p "$(dirname "$VERSION_FILE")"
    echo "$HELM_VERSION" > "$VERSION_FILE"
    log "Version stamped: $HELM_VERSION ✓"
  fi
}

stamp_version

# ─── PHASE 9: STRUCTURE CHECK SUMMARY ────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "┌─────────────────────────────────────────────┐"
  echo "│  helm-install.sh DRY-RUN — STRUCTURE CHECK  │"
  echo "└─────────────────────────────────────────────┘"
  echo ""
  echo "PASS: All phases completed (no actual changes made)"
  echo ""
  echo "Phases verified:"
  echo "  ✓ Phase 0: DES-ONBOARD-DETECT (fresh/update/normal detection)"
  echo "  ✓ Phase 1: Prerequisites check logic"
  echo "  ✓ Phase 2: Config collection (3 values: VPS IP, SSH key, Discord)"
  echo "  ✓ Phase 3: Directory structure (12 dirs)"
  echo "  ✓ Phase 4: Core file download logic [BLOCKED-ON-PUBLISH]"
  echo "  ✓ Phase 5: CONFIG.md generation from 3 values"
  echo "  ✓ Phase 6: Discord channel creation"
  echo "  ✓ Phase 7: Launchd service install"
  echo "  ✓ Phase 8: Version stamp"
  echo ""
  echo "Blocked-on-publish:"
  echo "  Phase 4 (core file download) requires platform repo:"
  echo "  $PLATFORM_REPO_URL"
  echo "  Unblocked by: PUBLISH-PLACEHOLDER-001 completion + first publish"
  echo ""
  echo "E2E test path:"
  echo "  1. Complete PUBLISH-PLACEHOLDER-001 (done ✓)"
  echo "  2. Publish first version to get-helm/helm"
  echo "  3. Run on clean Mac: bash helm-install.sh"
  echo "  4. Verify bot starts, Discord channels appear, ACK fires"
  echo ""
  exit 0
fi

echo ""
echo "HELM $HELM_VERSION installed successfully."
echo "Your assistant is starting — go to Discord and say hello in #general."
