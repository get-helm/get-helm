#!/bin/bash
# HELM Bootstrap — one-time Mac hardening for a new HELM host machine.
# Safe to run multiple times (idempotent).
# Run: bash ~/marvin-bot/pap-bootstrap.sh

set -e

echo "=== HELM Machine Hardening ==="

# 1. Screen lock: require password immediately on sleep/screensaver
echo "[1/5] Requiring password on screen lock..."
osascript -e 'tell application "System Events" to tell security preferences to set require password to wake to true' 2>/dev/null \
  || defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "    ✓ Screen lock password: immediate"

# 2. Screensaver: activate after 5 minutes of inactivity
echo "[2/5] Setting screensaver timeout to 5 min..."
defaults -currentHost write com.apple.screensaver idleTime -int 300
echo "    ✓ Screensaver: 5 min idle"

# 3. Disable automatic login (require password at boot)
echo "[3/5] Disabling automatic login..."
sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true
echo "    ✓ Auto-login: disabled"

# 4. Firewall: enable application firewall
echo "[4/5] Enabling application firewall..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null || true
echo "    ✓ Firewall: on (stealth mode enabled)"

# 5. FileVault check (cannot be automated — user must enable via System Settings)
echo "[5/5] Checking FileVault status..."
FVSTATUS=$(fdesetup status 2>/dev/null || echo "unknown")
if echo "$FVSTATUS" | grep -q "FileVault is On"; then
  echo "    ✓ FileVault: already enabled"
else
  echo ""
  echo "    ⚠️  FileVault is NOT enabled."
  echo "    To enable: System Settings → Privacy & Security → FileVault → Turn On"
  echo "    Save the recovery key to 1Password as 'Mac Mini FileVault Recovery Key'"
  echo ""
fi

echo ""
echo "=== HELM Bootstrap complete ==="
echo "If FileVault was not already on, enable it manually (instructions above)."
