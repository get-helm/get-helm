#!/usr/bin/env bash
# helm-recovery-install-wizard.sh
# Interactive 5-question wizard that generates a personalized RECOVERY-AI-PROMPT.md
# Run at HELM install time. Answers saved to ~/helm-workspace/recovery-config.json
# so Steward can re-run without re-asking.
#
# Usage: bash ~/marvin-bot/helm-recovery-install-wizard.sh
# Non-interactive (Steward re-run): bash ~/marvin-bot/helm-recovery-install-wizard.sh --from-config

set -euo pipefail

WORKSPACE="$HOME/helm-workspace"
TEMPLATE="$WORKSPACE/RECOVERY-AI-PROMPT.template.md"
OUTPUT="$WORKSPACE/RECOVERY-AI-PROMPT.md"
CONFIG_FILE="$WORKSPACE/recovery-config.json"
FROM_CONFIG=false

[[ "${1:-}" == "--from-config" ]] && FROM_CONFIG=true

# --- Template fill helper ---
fill_template() {
    local tmpl="$1"
    tmpl="${tmpl//\{\{DISCORD_SERVER_ID\}\}/$DISCORD_SERVER_ID}"
    tmpl="${tmpl//\{\{MACHINE_TYPE\}\}/$MACHINE_TYPE}"
    tmpl="${tmpl//\{\{VPS_ENABLED\}\}/$VPS_ENABLED}"
    tmpl="${tmpl//\{\{BOT_NAME\}\}/$BOT_NAME}"
    tmpl="${tmpl//\{\{SUPPORT_CONTACT\}\}/$SUPPORT_CONTACT}"
    printf '%s\n' "$tmpl"
}

# --- Load from saved config (Steward re-run path) ---
if [[ "$FROM_CONFIG" == "true" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: recovery-config.json not found — run wizard interactively first." >&2
        exit 1
    fi
    MACHINE_TYPE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['machine_type'])")
    VPS_ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['vps_enabled'])")
    SMART_PLUG_TYPE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['smart_plug_type'])")
    DISCORD_SERVER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['discord_server_id'])")
    SUPPORT_CONTACT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['support_contact'])")
    BOT_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['bot_name'])")
    echo "Loaded config from $CONFIG_FILE"
    echo "  machine_type=$MACHINE_TYPE  vps_enabled=$VPS_ENABLED"
    echo "  smart_plug=$SMART_PLUG_TYPE  discord_server_id=$DISCORD_SERVER_ID"
    echo "  support_contact=$SUPPORT_CONTACT  bot_name=$BOT_NAME"
else
    # --- Interactive wizard ---
    echo ""
    echo "=== HELM Recovery Setup — 5 Questions ==="
    echo "This takes about 2 minutes. Your answers are saved so you won't need to repeat them."
    echo ""

    # Q1: Machine type
    echo "Q1: What type of computer is running HELM?"
    echo "  1) Mac Mini"
    echo "  2) Mac (MacBook or other)"
    echo "  3) Windows PC"
    printf "Enter 1-3: "
    read -r q1_choice < /dev/tty
    case "$q1_choice" in
        1) MACHINE_TYPE="Mac Mini" ;;
        2) MACHINE_TYPE="Mac" ;;
        3) MACHINE_TYPE="Windows PC" ;;
        *) MACHINE_TYPE="Mac Mini" ; echo "  (defaulting to Mac Mini)" ;;
    esac

    # Q2: VPS
    echo ""
    echo "Q2: Do you have a remote server (VPS) set up for recovery access?"
    echo "  1) Yes"
    echo "  2) No / Not sure"
    printf "Enter 1-2: "
    read -r q2_choice < /dev/tty
    case "$q2_choice" in
        1) VPS_ENABLED="yes" ;;
        *) VPS_ENABLED="no" ;;
    esac

    # Q3: Smart plug
    echo ""
    echo "Q3: Do you have a smart plug connected to your HELM machine?"
    echo "  A smart plug lets you remotely cut and restore power if the machine freezes."
    echo "  1) Yes — TP-Link Kasa"
    echo "  2) Yes — other brand"
    echo "  3) No"
    printf "Enter 1-3: "
    read -r q3_choice < /dev/tty
    KASA_IP=""
    case "$q3_choice" in
        1)
            SMART_PLUG_TYPE="TP-Link Kasa"
            echo "  To find the plug's IP: open the Kasa app → tap your plug → tap the settings gear → Device Info."
            printf "    Plug IP address (e.g. 192.168.1.100): "
            read -r KASA_IP < /dev/tty
            [[ -z "$KASA_IP" ]] && echo "  (no IP entered — power-cycle button will be disabled until configured)"
            ;;
        2)
            printf "    Brand name: "
            read -r SMART_PLUG_TYPE < /dev/tty
            [[ -z "$SMART_PLUG_TYPE" ]] && SMART_PLUG_TYPE="smart plug (brand not specified)"
            ;;
        *) SMART_PLUG_TYPE="none" ;;
    esac

    # Q4: Discord server ID
    echo ""
    echo "Q4: What is your Discord server ID?"
    echo "  How to find it: Open Discord → right-click your server name → Copy Server ID"
    echo "  (Enable Developer Mode first: User Settings → Advanced → Developer Mode)"
    echo "  Press Enter to skip — you can add it later."
    printf "Server ID: "
    read -r DISCORD_SERVER_ID < /dev/tty
    [[ -z "$DISCORD_SERVER_ID" ]] && DISCORD_SERVER_ID="(your Discord server ID — add this after enabling Developer Mode)"

    # Q5: Support contact
    echo ""
    echo "Q5: Who should you contact if HELM can't recover on its own?"
    echo "  This is shown in your recovery guide as the last resort contact."
    echo "  Enter an email address or Discord handle (e.g. you@example.com or @username)"
    printf "Support contact: "
    read -r SUPPORT_CONTACT < /dev/tty
    [[ -z "$SUPPORT_CONTACT" ]] && SUPPORT_CONTACT="(your support contact)"

    # Bot name: prefer CONFIG.md, fall back to default
    BOT_NAME="Marvin"
    if [[ -f "$WORKSPACE/CONFIG.md" ]]; then
        NAME_FROM_CONFIG=$(grep -m1 "^AGENT_NAME:" "$WORKSPACE/CONFIG.md" 2>/dev/null | awk -F': ' '{print $2}' | xargs || true)
        [[ -n "$NAME_FROM_CONFIG" ]] && BOT_NAME="$NAME_FROM_CONFIG"
    fi
    if [[ -f "$WORKSPACE/ABOUT-ME.md" ]]; then
        NAME_FROM_ABOUT=$(grep -m1 "^AGENT_NAME=" "$WORKSPACE/ABOUT-ME.md" 2>/dev/null | awk -F'=' '{print $2}' | xargs || true)
        [[ -n "$NAME_FROM_ABOUT" ]] && BOT_NAME="$NAME_FROM_ABOUT"
    fi

    # Save config for steward re-runs
    python3 -c "
import json
config = {
    'machine_type': '''$MACHINE_TYPE''',
    'vps_enabled': '''$VPS_ENABLED''',
    'smart_plug_type': '''$SMART_PLUG_TYPE''',
    'kasa_ip': '''$KASA_IP''',
    'discord_server_id': '''$DISCORD_SERVER_ID''',
    'support_contact': '''$SUPPORT_CONTACT''',
    'bot_name': '''$BOT_NAME''',
    'configured_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    echo ""
    echo "Config saved to recovery-config.json"
fi

# --- Write kasa-config.json to workspace if TP-Link Kasa configured ---
KASA_IP_RESOLVED="${KASA_IP:-}"
if [[ -z "$KASA_IP_RESOLVED" ]] && [[ -f "$CONFIG_FILE" ]]; then
    KASA_IP_RESOLVED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('kasa_ip',''))" 2>/dev/null || true)
fi
if [[ -n "$KASA_IP_RESOLVED" ]] && [[ "$KASA_IP_RESOLVED" != "none" ]]; then
    python3 -c "
import json
kasa_cfg = {'ip': '''$KASA_IP_RESOLVED''', 'type': 'kasa', 'configured_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'}
with open('$WORKSPACE/kasa-config.json', 'w') as f:
    json.dump(kasa_cfg, f, indent=2)
"
    echo "Smart plug config saved — power-cycle button enabled in recovery page."
fi

# --- Verify template ---
if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: Template not found at $TEMPLATE" >&2
    echo "Ensure RECOVERY-AI-PROMPT.template.md exists in your workspace." >&2
    exit 1
fi

# --- Fill template and write output ---
GENERATED=$(fill_template "$(cat "$TEMPLATE")")
printf '%s\n' "$GENERATED" > "$OUTPUT"

echo ""
echo "=== Recovery prompt generated ==="
echo "  File: $OUTPUT"
echo "  Bot: $BOT_NAME | Machine: $MACHINE_TYPE | VPS: $VPS_ENABLED | Smart plug: $SMART_PLUG_TYPE"

# --- Create desktop shortcut (macOS only) ---
SHORTCUT_CREATOR="$(dirname "$0")/create-helm-shortcut.sh"
if [[ "$(uname)" == "Darwin" ]] && [[ -f "$SHORTCUT_CREATOR" ]]; then
    echo ""
    echo "Creating 'Fix HELM' desktop shortcut..."
    bash "$SHORTCUT_CREATOR" || echo "  (shortcut creation failed — run create-helm-shortcut.sh manually)"
fi

echo ""
echo "Next steps:"
echo "  1. Push RECOVERY-AI-PROMPT.md to GitHub so you can access it when HELM is offline."
echo "  2. Bookmark the raw GitHub URL on your phone."
echo "  3. If you enabled a smart plug, set it up now while HELM is healthy."
echo "  4. If a VPS recovery page is configured, save the URL to your phone's home screen."
