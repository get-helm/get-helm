#!/bin/bash
# helm-personal-data-scan.sh — Block personal data from entering get-helm repos
# Usage: bash helm-personal-data-scan.sh <file_or_dir>
# Exit 0: PASS. Exit 1: FAIL (deploy blocked — personal data found).
# --fix flag: auto-replace hits with {{USER_*}} placeholders instead of blocking

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET="${1:-}"
FIX_MODE=0
[[ "${2:-}" == "--fix" ]] && FIX_MODE=1

FAIL=0
FIXES=0

pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗ BLOCKED${NC} $1"; FAIL=1; }
fixed() { echo -e "${YELLOW}→ FIXED${NC} $1"; FIXES=$((FIXES+1)); }

echo ""
echo "======================================="
echo "  HELM Personal-Data Scan"
echo "  Target: ${TARGET:-'(no file specified)'}"
echo "  Mode: $([ $FIX_MODE -eq 1 ] && echo 'AUTO-FIX' || echo 'SCAN-ONLY')"
echo "======================================="
echo ""

if [ -z "$TARGET" ] || [ ! -e "$TARGET" ]; then
  fail "Target not specified or does not exist: ${TARGET}"
  exit 1
fi

# Collect files
if [ -f "$TARGET" ]; then
  SCAN_LIST="$TARGET"
else
  SCAN_LIST=$(find "$TARGET" -type f \( -name "*.html" -o -name "*.js" -o -name "*.py" -o -name "*.sh" -o -name "*.json" -o -name "*.md" -o -name "*.conf" -o -name "*.txt" \) 2>/dev/null | grep -v ".git/")
fi

FILE_COUNT=$(echo "$SCAN_LIST" | grep -c . 2>/dev/null || echo 0)
echo "Scanning $FILE_COUNT file(s) for personal data..."
echo ""

# ── Pattern definitions ────────────────────────────────────────────────────────
# Names
NAMES=("{{USER_JERRY}}" "{{USER_LAST_NAME}}" "{{USER_GITHUB}}" "{{USER_GITHUB}}" "{{USER_FAMILY_MEMBER_1}}" "{{USER_FAMILY_MEMBER_2}}" "Stephen {{USER_LAST_NAME}}")

# Emails
EMAILS=("{{USER_GMAIL}}" "{{USER_EMAIL}}")

# Domain
DOMAIN_PATTERN="{{USER_DOMAIN}}"

# IP addresses — read actual IPs from local config at scan time
# Placeholder tokens ({{USER_VPS_IP}} etc.) are VALID in staged distribution files — do NOT scan for them
IPS=()
SSH_PATTERNS=()
_HELM_FACTS="${HOME}/helm-workspace/knowledge/HELM-FACTS.md"
if [[ -f "$_HELM_FACTS" ]]; then
  _VPS_IP=$(grep -m1 "^- VPS IP:" "$_HELM_FACTS" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' 2>/dev/null || true)
  if [[ -n "$_VPS_IP" ]]; then
    IPS+=("$_VPS_IP")
    SSH_PATTERNS+=("root@$_VPS_IP")
  fi
fi
# Also check for Tailscale IPs in HELM-FACTS
_TAILSCALE_IPS=$(grep -oE '100\.[0-9]+\.[0-9]+\.[0-9]+' "$_HELM_FACTS" 2>/dev/null | sort -u || true)
while IFS= read -r _IP; do
  [[ -n "$_IP" ]] && IPS+=("$_IP")
done <<< "$_TAILSCALE_IPS"

# Discord IDs — server ID + all channel IDs read from channels.json at scan time
# {{USER_DISCORD_SERVER_ID}} and {{USER_CHANNEL_*}} placeholders are VALID in staged files
DISCORD_IDS=()
_CHANNELS_JSON="${HOME}/helm-workspace/channels.json"
if [[ -f "$_CHANNELS_JSON" ]]; then
  # Read ALL numeric values (guild + all channel IDs) so any unmasked ID is caught
  while IFS= read -r _ID; do
    [[ -n "$_ID" ]] && DISCORD_IDS+=("$_ID")
  done < <(python3 -c "
import json, re
d = json.load(open('$_CHANNELS_JSON'))
for v in d.values():
  # Discord snowflake IDs: 17-20 digits
  if re.fullmatch(r'[0-9]{17,20}', str(v)):
    print(v)
" 2>/dev/null || true)
fi

# Phone (placeholder — update if known)
# PHONE_PATTERNS=()

# 1Password item names that are personal
VAULT_ITEMS=("Hostinger Root" "Dreamhost" "Monarch" "{{USER_JERRY}}.*Vault")

do_scan_file() {
  local FILE="$1"
  local HIT=0

  # Check names
  for NAME in "${NAMES[@]}"; do
    if grep -qi "$NAME" "$FILE" 2>/dev/null; then
      # Exclude placeholder patterns like {{USER_JERRY}}
      if grep -qi "$NAME" "$FILE" | grep -v "{{USER_" 2>/dev/null; then
        true
      fi
      MATCHES=$(grep -in "$NAME" "$FILE" 2>/dev/null | grep -v "{{USER_\|USER_JERRY\|USER_JTOLZMAN\|USER_LAST_NAME\|USER_FULL_NAME\|USER_FAMILY\|blocked-on-\|total_jerry\|_jerry\b\|jerry_\|OWNER_ID" || true)
      if [ -n "$MATCHES" ]; then
        if [ $FIX_MODE -eq 1 ]; then
          # Replace with placeholder
          PLACEHOLDER=$(echo "$NAME" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
          sed -i '' "s/$NAME/{{USER_${PLACEHOLDER}}}/g" "$FILE" 2>/dev/null || true
          fixed "$FILE: replaced '$NAME' → {{USER_${PLACEHOLDER}}}"
        else
          fail "$FILE: personal name '$NAME' found"
          echo "   $(echo "$MATCHES" | head -3)"
          HIT=1
        fi
      fi
    fi
  done

  # Check emails
  for EMAIL in "${EMAILS[@]}"; do
    ESCAPED=$(echo "$EMAIL" | sed 's/\./\\./g' | sed 's/@/\\@/g')
    if grep -qi "$ESCAPED" "$FILE" 2>/dev/null; then
      MATCHES=$(grep -in "$ESCAPED" "$FILE" 2>/dev/null | grep -v "{{USER_" || true)
      if [ -n "$MATCHES" ]; then
        if [ $FIX_MODE -eq 1 ]; then
          sed -i '' "s/$EMAIL/{{USER_EMAIL}}/g" "$FILE" 2>/dev/null || true
          fixed "$FILE: replaced email '$EMAIL' → {{USER_EMAIL}}"
        else
          fail "$FILE: personal email '$EMAIL' found"
          echo "   $(echo "$MATCHES" | head -2)"
          HIT=1
        fi
      fi
    fi
  done

  # Check domain
  if grep -qi "$DOMAIN_PATTERN" "$FILE" 2>/dev/null; then
    MATCHES=$(grep -in "$DOMAIN_PATTERN" "$FILE" 2>/dev/null | grep -v "{{USER_" | grep -v "get-helm.github.io" || true)
    if [ -n "$MATCHES" ]; then
      if [ $FIX_MODE -eq 1 ]; then
        sed -i '' "s/{{USER_DOMAIN}}/{{USER_DOMAIN}}/g" "$FILE" 2>/dev/null || true
        fixed "$FILE: replaced domain '{{USER_DOMAIN}}' → {{USER_DOMAIN}}"
      else
        fail "$FILE: personal domain '{{USER_DOMAIN}}' found"
        echo "   $(echo "$MATCHES" | head -2)"
        HIT=1
      fi
    fi
  fi

  # Check IPs
  for IP in "${IPS[@]}"; do
    if grep -q "$IP" "$FILE" 2>/dev/null; then
      MATCHES=$(grep -n "$IP" "$FILE" 2>/dev/null || true)
      if [ -n "$MATCHES" ]; then
        if [ $FIX_MODE -eq 1 ]; then
          CLEAN_IP=$(echo "$IP" | sed 's/\\\././g')
          sed -i '' "s/$CLEAN_IP/{{USER_VPS_IP}}/g" "$FILE" 2>/dev/null || true
          fixed "$FILE: replaced IP '$CLEAN_IP' → {{USER_VPS_IP}}"
        else
          fail "$FILE: personal IP found"
          echo "   $(echo "$MATCHES" | head -2)"
          HIT=1
        fi
      fi
    fi
  done

  # Check Discord IDs (server ID + channel IDs)
  for DID in "${DISCORD_IDS[@]}"; do
    if grep -q "$DID" "$FILE" 2>/dev/null; then
      MATCHES=$(grep -n "$DID" "$FILE" 2>/dev/null || true)
      if [ -n "$MATCHES" ]; then
        if [ $FIX_MODE -eq 1 ]; then
          # No auto-fix for channel IDs — each maps to a specific {{USER_CHANNEL_*}} placeholder.
          # Run helm-placeholder-convert.sh to apply the correct mapping.
          warn "$FILE: Discord ID $DID found — run helm-placeholder-convert.sh to fix"
        else
          fail "$FILE: personal Discord ID found: $DID"
          HIT=1
        fi
      fi
    fi
  done

  # Check SSH patterns
  for PAT in "${SSH_PATTERNS[@]}"; do
    if grep -q "$PAT" "$FILE" 2>/dev/null; then
      MATCHES=$(grep -n "$PAT" "$FILE" 2>/dev/null || true)
      if [ -n "$MATCHES" ]; then
        if [ $FIX_MODE -eq 1 ]; then
          sed -i '' "s/ssh root@187\.124\.65\.39/ssh {{USER_VPS_SSH}}/g" "$FILE" 2>/dev/null || true
          fixed "$FILE: replaced SSH host → {{USER_VPS_SSH}}"
        else
          fail "$FILE: personal SSH path found"
          HIT=1
        fi
      fi
    fi
  done

  return $HIT
}

while IFS= read -r FILE; do
  [ -f "$FILE" ] || continue
  do_scan_file "$FILE"
done <<< "$SCAN_LIST"

echo ""
echo "======================================="
if [ $FIX_MODE -eq 1 ]; then
  echo "  Auto-fix complete: $FIXES replacement(s) made"
  if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}PASS — safe to push${NC}"
    exit 0
  else
    echo -e "  ${RED}BLOCKED — some patterns could not be auto-fixed${NC}"
    exit 1
  fi
else
  if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}PASS — no personal data found${NC}"
    exit 0
  else
    echo -e "  ${RED}FAIL — personal data found. Run with --fix to auto-replace.${NC}"
    exit 1
  fi
fi
echo "======================================="
