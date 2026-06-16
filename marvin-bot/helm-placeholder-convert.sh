#!/bin/bash
# helm-placeholder-convert.sh — Replace personal values with {{USER_*}} placeholders in staged files
# Called by helm-publish.sh after Stage 1 (staging) and before Stage 2 (scan)
# Reads canonical token list from placeholder-manifest.json (PLACEHOLDER-LIFECYCLE-001).
#
# Conversion rules are defined in this script; manifest defines the token namespace.
# After conversion: asserts no orphan tokens exist (tokens in files not in manifest).
#
# Usage: helm-placeholder-convert.sh STAGING_DIR
# Exit 0: conversion applied | Exit 1: error or orphan tokens found

set -euo pipefail

STAGING_DIR="${1:-}"
if [[ -z "$STAGING_DIR" || ! -d "$STAGING_DIR" ]]; then
  echo "Usage: helm-placeholder-convert.sh STAGING_DIR" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/placeholder-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: placeholder-manifest.json not found at $MANIFEST" >&2
  exit 1
fi

echo ""
echo "--- 1b: Placeholder conversion ---"

CONVERTED=0
SKIPPED=0

# Process only text files (md, json, sh, js, yaml, txt)
while IFS= read -r file; do
  # Skip binary files
  if ! file -b "$file" | grep -qiE "text|empty"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Run substitutions in order (most specific first to avoid double-replacement)
  # Also handles canonical alias consolidation:
  #   USER_JTOLZMAN → USER_GITHUB  (same value: {{USER_GITHUB}})
  #   USER_NAME → USER_JERRY       (same value: {{USER_JERRY}})
  #   USER_PREFERRED_NAME → USER_JERRY
  CHANGED=$(python3 -c "
import sys, re
content = open(sys.argv[1]).read()
orig = content

# Order matters: most specific first
replacements = [
    # Email addresses — before domain replacement
    (r'junk@{{USER_DOMAIN}}', '{{USER_EMAIL_ALT}}'),
    (r'invest@{{USER_DOMAIN}}', '{{USER_EMAIL_ALT}}'),
    (r'jerry@{{USER_DOMAIN}}', '{{USER_EMAIL}}'),
    (r'{{USER_GITHUB}}@gmail\.com', '{{USER_GMAIL}}'),
    # IP addresses — before general domain/name replacement
    (r'jerry@100\.96\.251\.61', '{{USER_SSH_HOST}}'),
    (r'100\.105\.219\.31', '{{USER_VPS_TAILSCALE_IP}}'),
    (r'100\.96\.251\.61', '{{USER_MAC_TAILSCALE_IP}}'),
    (r'187\.124\.65\.39', '{{USER_VPS_IP}}'),
    # Names and domain
    (r'{{USER_FULL_NAME}}', '{{USER_FULL_NAME}}'),
    (r'{{USER_FAMILY_MEMBER_1}}', '{{USER_FAMILY_MEMBER_1}}'),
    (r'{{USER_FAMILY_MEMBER_2}}', '{{USER_FAMILY_MEMBER_2}}'),
    (r'tolzman\\\.com', '{{USER_DOMAIN}}'),  # escaped-dot form (in JS regex / sh patterns)
    (r'{{USER_DOMAIN}}', '{{USER_DOMAIN}}'),
    (r'/Users/jerry(?=/|\'|\"|$|\s)', '/Users/{{USER_HOME}}'),
    (r'\bjtolzman13\b', '{{USER_GITHUB}}'),
    (r'\bjtolzman\b', '{{USER_GITHUB}}'),
    (r'\bJerry\b', '{{USER_JERRY}}'),
    (r'\bTolzman\b', '{{USER_LAST_NAME}}'),
    (r'{{USER_DISCORD_SERVER_ID}}', '{{USER_DISCORD_SERVER_ID}}'),
    # Channel IDs — must come after server ID to avoid partial matches
    (r'{{USER_CHANNEL_HELM_IMPROVEMENTS}}', '{{USER_CHANNEL_HELM_IMPROVEMENTS}}'),
    (r'{{USER_CHANNEL_HELM_AUDIT}}', '{{USER_CHANNEL_HELM_AUDIT}}'),
    (r'{{USER_CHANNEL_HELM_STATUS}}', '{{USER_CHANNEL_HELM_STATUS}}'),
    (r'{{USER_CHANNEL_BETA_USERS}}', '{{USER_CHANNEL_BETA_USERS}}'),
    (r'{{USER_CHANNEL_AGENT_BOARD}}', '{{USER_CHANNEL_AGENT_BOARD}}'),
    # Additional standard channel IDs (PUBLISH-PII-CHANNELS-001)
    (r'{{USER_CHANNEL_GENERAL}}', '{{USER_CHANNEL_GENERAL}}'),
    (r'{{USER_CHANNEL_RECOVERY}}', '{{USER_CHANNEL_RECOVERY}}'),
    # Workspace-specific channel IDs — genericized for distribution
    (r'{{USER_CHANNEL_ETF_TRACKER}}', '{{USER_CHANNEL_ETF_TRACKER}}'),
    (r'{{USER_CHANNEL_OPTIONS_HELPER}}', '{{USER_CHANNEL_OPTIONS_HELPER}}'),
    # User-specific IDs
    (r'{{USER_DISCORD_USER_ID}}', '{{USER_DISCORD_USER_ID}}'),
    # {{USER_JERRY}}-PROFILE filename pattern (all-caps, in file path references)
    (r'{{USER_JERRY}}-PROFILE', '{{USER_JERRY}}-PROFILE'),
]

for pattern, replacement in replacements:
    content = re.sub(pattern, replacement, content)

# Canonical alias consolidation: normalize non-canonical tokens to canonical ones
aliases = {
    '{{USER_GITHUB}}': '{{USER_GITHUB}}',
    '{{USER_JERRY}}': '{{USER_JERRY}}',
    '{{USER_JERRY}}': '{{USER_JERRY}}',
    '{{USER_HOME}}': '{{USER_HOME}}',
}
for alias, canonical in aliases.items():
    content = content.replace(alias, canonical)

if content != orig:
    open(sys.argv[1], 'w').write(content)
    print('changed')
else:
    print('unchanged')
" "$file" 2>/dev/null || echo "error")

  if [[ "$CHANGED" == "changed" ]]; then
    echo "  → $(basename "$file") (placeholders applied)"
    CONVERTED=$((CONVERTED + 1))
  fi
done < <(find "$STAGING_DIR" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" -o -name "*.js" -o -name "*.yaml" -o -name "*.txt" -o -name "*.py" \) | sort)

echo "  ✓ Placeholder conversion complete: $CONVERTED file(s) updated"
echo ""

# --- Orphan token scan ---
# Assert: every {{USER_*}} token in shipped files exists in the manifest
echo "--- 1c: Orphan token scan ---"

MANIFEST_TOKENS=$(python3 -c "
import json, sys
m = json.load(open('$MANIFEST'))
tokens = [k for k in m if not k.startswith('_')]
# Include canonical aliases as valid tokens
aliases = m.get('_canonical_aliases', {})
all_valid = set(tokens) | set(aliases.keys())
print('\n'.join(sorted(all_valid)))
")

ORPHAN_FOUND=0
while IFS= read -r file; do
  if ! file -b "$file" | grep -qiE "text|empty"; then continue; fi
  # Extract all {{USER_*}} tokens from the file
  FILE_TOKENS=$(grep -oE '\{\{USER_[A-Z0-9_]+\}\}' "$file" 2>/dev/null | sort -u || true)
  if [[ -z "$FILE_TOKENS" ]]; then continue; fi
  while IFS= read -r token; do
    TOKEN_NAME="${token//\{\{/}"
    TOKEN_NAME="${TOKEN_NAME//\}\}/}"
    if ! echo "$MANIFEST_TOKENS" | grep -qx "$TOKEN_NAME"; then
      echo "  ⚠️ ORPHAN TOKEN: $token in $(basename "$file") — not in placeholder-manifest.json"
      ORPHAN_FOUND=$((ORPHAN_FOUND + 1))
    fi
  done <<< "$FILE_TOKENS"
done < <(find "$STAGING_DIR" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" -o -name "*.js" -o -name "*.yaml" -o -name "*.txt" -o -name "*.py" \) | sort)

if [[ $ORPHAN_FOUND -gt 0 ]]; then
  echo "  ❌ ORPHAN SCAN FAILED: $ORPHAN_FOUND unknown token(s) found — add them to placeholder-manifest.json"
  exit 1
else
  echo "  ✓ Orphan scan PASS: all {{USER_*}} tokens are in the manifest"
fi
echo ""
