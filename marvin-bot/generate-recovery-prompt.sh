#!/usr/bin/env bash
# generate-recovery-prompt.sh
# Fills RECOVERY-AI-PROMPT.template.md with actual install values from CONFIG.md
# Run once at install, and by Steward weekly to keep values current
# Output: ~/helm-workspace/RECOVERY-AI-PROMPT.md (the user-facing generated copy)

set -euo pipefail

WORKSPACE="$HOME/helm-workspace"
TEMPLATE="$WORKSPACE/recovery/RECOVERY-AI-PROMPT.template.md"
OUTPUT="$WORKSPACE/recovery/RECOVERY-AI-PROMPT.md"
CONFIG="$WORKSPACE/CONFIG.md"
ABOUT_ME="$WORKSPACE/ABOUT-ME.md"
RECOVERY_CONFIG="$WORKSPACE/recovery-config.json"

# --- Prefer recovery-config.json (wizard output) over CONFIG.md ---
if [[ -f "$RECOVERY_CONFIG" ]]; then
    BOT_NAME=$(python3 -c "import json; print(json.load(open('$RECOVERY_CONFIG'))['bot_name'])" 2>/dev/null || true)
    DISCORD_SERVER_ID=$(python3 -c "import json; print(json.load(open('$RECOVERY_CONFIG'))['discord_server_id'])" 2>/dev/null || true)
    SUPPORT_CONTACT=$(python3 -c "import json; print(json.load(open('$RECOVERY_CONFIG'))['support_contact'])" 2>/dev/null || true)
    MACHINE_TYPE=$(python3 -c "import json; print(json.load(open('$RECOVERY_CONFIG'))['machine_type'])" 2>/dev/null || true)
    VPS_ENABLED=$(python3 -c "import json; print(json.load(open('$RECOVERY_CONFIG'))['vps_enabled'])" 2>/dev/null || true)
    echo "Using recovery-config.json (wizard values)"
else
    # --- Fallback: read CONFIG.md values ---
    read_config() {
        local key="$1"
        grep -m1 "^${key}:" "$CONFIG" 2>/dev/null | awk -F': ' '{print $2}' | xargs
    }

    read_about_me() {
        local key="$1"
        grep -m1 "^${key}=" "$ABOUT_ME" 2>/dev/null | awk -F'=' '{print $2}' | xargs
    }

    BOT_NAME=$(read_config "AGENT_NAME")
    DISCORD_SERVER_ID=$(read_about_me "DISCORD_SERVER_ID")
    SUPPORT_CONTACT=$(read_config "FALLBACK_CONTACT")

    # Fallbacks if CONFIG keys missing
    [ -z "$BOT_NAME" ] && BOT_NAME=$(read_about_me "AGENT_NAME")
    [ -z "$BOT_NAME" ] && BOT_NAME="your PAP agent"
    [ -z "$DISCORD_SERVER_ID" ] && DISCORD_SERVER_ID="(your Discord server ID)"
    [ -z "$SUPPORT_CONTACT" ] && SUPPORT_CONTACT="(your support contact)"

    # --- Detect machine type ---
    MACHINE_TYPE="Mac Mini"
    if [[ -f /usr/sbin/ioreg ]]; then
        MODEL=$(/usr/sbin/ioreg -l 2>/dev/null | grep "product-name" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
        [ -n "$MODEL" ] && MACHINE_TYPE="$MODEL"
    fi

    # --- Detect VPS enabled ---
    VPS_ENABLED="no"
    if [[ -f "$HOME/marvin-bot/pap-heartbeat.sh" ]]; then
        VPS_ENABLED="yes"
    fi
fi

# --- Verify template exists ---
if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: Template not found at $TEMPLATE" >&2
    echo "Pull the latest helm-config and ensure RECOVERY-AI-PROMPT.template.md is present." >&2
    exit 1
fi

# --- Fill template ---
GENERATED=$(cat "$TEMPLATE")
GENERATED="${GENERATED//\{\{DISCORD_SERVER_ID\}\}/$DISCORD_SERVER_ID}"
GENERATED="${GENERATED//\{\{MACHINE_TYPE\}\}/$MACHINE_TYPE}"
GENERATED="${GENERATED//\{\{VPS_ENABLED\}\}/$VPS_ENABLED}"
GENERATED="${GENERATED//\{\{BOT_NAME\}\}/$BOT_NAME}"
GENERATED="${GENERATED//\{\{SUPPORT_CONTACT\}\}/$SUPPORT_CONTACT}"

# --- Write output ---
printf '%s\n' "$GENERATED" > "$OUTPUT"

echo "Generated: $OUTPUT"
echo "  BOT_NAME=$BOT_NAME"
echo "  DISCORD_SERVER_ID=$DISCORD_SERVER_ID"
echo "  MACHINE_TYPE=$MACHINE_TYPE"
echo "  VPS_ENABLED=$VPS_ENABLED"
echo "  SUPPORT_CONTACT=$SUPPORT_CONTACT"
