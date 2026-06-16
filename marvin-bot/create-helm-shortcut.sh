#!/usr/bin/env bash
# create-helm-shortcut.sh
# Creates a "Fix HELM" desktop shortcut on the clean machine.
# Double-clicking it opens Claude Code in the HELM workspace with recovery context.
# Run at HELM install time (called by helm-recovery-install-wizard.sh or manually).
#
# Usage: bash ~/marvin-bot/create-helm-shortcut.sh

set -euo pipefail

WORKSPACE="$HOME/helm-workspace"
DESKTOP="$HOME/Desktop"
SHORTCUT_NAME="Fix HELM.command"
SHORTCUT="$DESKTOP/$SHORTCUT_NAME"

# Detect Claude Code binary
CLAUDE_BIN=""
for candidate in "$HOME/.claude/local/claude" "/usr/local/bin/claude" "$(which claude 2>/dev/null)"; do
    [[ -z "$candidate" ]] && continue
    if command -v "$candidate" &>/dev/null 2>&1 || [[ -x "$candidate" ]]; then
        CLAUDE_BIN="$candidate"
        break
    fi
done

if [[ -z "$CLAUDE_BIN" ]]; then
    echo "WARNING: Claude Code not found. The shortcut will try 'claude' from PATH."
    CLAUDE_BIN="claude"
fi

# Create the .command file (double-clickable shell script on macOS)
cat > "$SHORTCUT" << SHORTCUT_EOF
#!/usr/bin/env bash
# Fix HELM — opens Claude Code with HELM recovery context
# Double-click this file to launch

# Change to HELM workspace
cd "$WORKSPACE"

# Recovery prompt for Claude
PROMPT="I need help with HELM — my automation platform. The bot may not be responding in Discord.

Please check:
1. Is the bot process running? (pgrep -f bot.js)
2. What do the last 20 lines of ~/marvin-bot/marvin.log say?
3. What is the current bot start time? (cat ~/helm-workspace/bot-start.txt)

Based on what you find, either restart the bot or explain what's wrong."

echo "Opening Claude Code with HELM recovery context..."
echo "If this doesn't open automatically, run: cd $WORKSPACE && claude"
echo ""

# Try to open Claude Code with the recovery prompt
if command -v "$CLAUDE_BIN" &>/dev/null 2>&1 || [[ -x "$CLAUDE_BIN" ]]; then
    "$CLAUDE_BIN" --print "\$PROMPT" 2>/dev/null || "$CLAUDE_BIN"
else
    echo "Claude Code not found at $CLAUDE_BIN"
    echo "Install it from: https://claude.ai/code"
    echo ""
    echo "Once installed, run:"
    echo "  cd $WORKSPACE && claude"
    read -p "Press Enter to close..."
fi
SHORTCUT_EOF

chmod +x "$SHORTCUT"

# Set a custom icon (using the generic document icon) — optional cosmetic step
# xattr -wx com.apple.FinderInfo ... would be needed for a real icon; skip for now

echo "Shortcut created: $SHORTCUT"
echo "Double-click 'Fix HELM.command' on your Desktop to open Claude Code."
echo ""

# macOS Gatekeeper: mark as user-approved so it runs without the 'unidentified developer' warning
if command -v xattr &>/dev/null; then
    xattr -d com.apple.quarantine "$SHORTCUT" 2>/dev/null || true
fi

echo "NOTE: The first time you double-click it, macOS may ask if you trust the script."
echo "Click 'Open' to proceed."
