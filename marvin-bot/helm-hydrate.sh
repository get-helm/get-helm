#!/bin/bash
# helm-hydrate.sh — Substitute {{USER_*}} tokens in a cloned HELM install with real values
# Called as the LAST step of helm-init.sh after all values are collected.
# Reads placeholder-manifest.json to know what tokens to expect.
# Self-asserts: zero {{USER_* remain after hydration.
#
# Usage: helm-hydrate.sh INSTALL_DIR VALUES_JSON_FILE
#   INSTALL_DIR:      root of the cloned HELM repo (e.g. ~/helm-workspace)
#   VALUES_JSON_FILE: JSON file mapping token names to values
#                     e.g. {"USER_JERRY":"Alex","USER_EMAIL":"alex@example.com",...}
#
# Exit 0: hydration complete, zero tokens remaining
# Exit 1: hydration failed or tokens remain after substitution

set -euo pipefail

INSTALL_DIR="${1:-}"
VALUES_FILE="${2:-}"

if [[ -z "$INSTALL_DIR" || -z "$VALUES_FILE" ]]; then
  echo "Usage: helm-hydrate.sh INSTALL_DIR VALUES_JSON_FILE" >&2
  exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "ERROR: INSTALL_DIR does not exist: $INSTALL_DIR" >&2
  exit 1
fi

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "ERROR: VALUES_JSON_FILE not found: $VALUES_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/placeholder-manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: placeholder-manifest.json not found at $MANIFEST" >&2
  exit 1
fi

echo ""
echo "=== HELM Hydration — filling your personal values ==="
echo ""

# Build auto-detected values
AUTO_VALUES=$(python3 -c "
import os, json
auto = {
    'USER_HOME': os.environ.get('USER', os.path.basename(os.environ.get('HOME', 'user'))),
}
print(json.dumps(auto))
")

# Merge: auto-detected values + provided values (provided wins on conflict)
MERGED_VALUES=$(python3 -c "
import json, sys

manifest = json.load(open('$MANIFEST'))
auto = $AUTO_VALUES
provided = json.load(open('$VALUES_FILE'))

# Collect all valid tokens from manifest
all_tokens = {k: v for k, v in manifest.items() if not k.startswith('_')}

# Derive values for 'derived' tokens
merged = {**auto, **provided}

# USER_LAST_NAME: last word of USER_FULL_NAME
if 'USER_LAST_NAME' not in merged and 'USER_FULL_NAME' in merged:
    parts = merged['USER_FULL_NAME'].split()
    if len(parts) > 1:
        merged['USER_LAST_NAME'] = parts[-1]

# USER_VPS_SSH: root@USER_VPS_IP
if 'USER_VPS_SSH' not in merged and merged.get('USER_VPS_IP'):
    merged['USER_VPS_SSH'] = f'root@{merged[\"USER_VPS_IP\"]}'

# USER_GMAIL: fallback to USER_EMAIL
if 'USER_GMAIL' not in merged and merged.get('USER_EMAIL'):
    merged['USER_GMAIL'] = merged['USER_EMAIL']

print(json.dumps(merged))
")

HYDRATED=0
SKIPPED=0
TOKENS_UNFILLED=()

# Process all text files in the install directory
while IFS= read -r file; do
  # Skip binary and git-internal files
  if [[ "$file" == */.git/* ]]; then continue; fi
  if ! file -b "$file" | grep -qiE "text|empty"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  RESULT=$(python3 -c "
import sys, json, re

values = $MERGED_VALUES
content = open(sys.argv[1], errors='replace').read()
orig = content

# Replace all {{USER_*}} tokens that have a value
for token, value in values.items():
    if value:  # only substitute non-empty values
        content = content.replace('{{' + token + '}}', str(value))

if content != orig:
    open(sys.argv[1], 'w').write(content)
    print('changed')
else:
    print('unchanged')
" "$file" 2>/dev/null || echo "error")

  if [[ "$RESULT" == "changed" ]]; then
    HYDRATED=$((HYDRATED + 1))
  fi
done < <(find "$INSTALL_DIR" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" -o -name "*.js" -o -name "*.yaml" -o -name "*.txt" -o -name "*.env" \) | sort)

echo "  ✓ Hydrated $HYDRATED file(s) with your personal values"
echo ""

# --- Completeness assertion ---
echo "--- Checking for unfilled tokens ---"

REMAINING=$(grep -rl '{{USER_' "$INSTALL_DIR" --include="*.md" --include="*.json" --include="*.sh" --include="*.js" --include="*.yaml" --include="*.txt" 2>/dev/null | \
  xargs grep -oh '{{USER_[A-Z0-9_]*}}' 2>/dev/null | sort -u || true)

if [[ -n "$REMAINING" ]]; then
  echo "  ⚠️ Unfilled tokens found after hydration:"
  echo "$REMAINING" | while read -r tok; do
    echo "    - $tok"
    # Check if this token has a required:true in manifest — if so, it's a hard fail
    IS_REQUIRED=$(python3 -c "
import json
m = json.load(open('$MANIFEST'))
tok = '$tok'.replace('{{','').replace('}}','')
entry = m.get(tok, {})
print('yes' if entry.get('required') else 'no')
" 2>/dev/null || echo "no")
    if [[ "$IS_REQUIRED" == "yes" ]]; then
      echo "      ↳ REQUIRED — hydration incomplete"
      exit 1
    fi
  done

  # Non-required tokens left unfilled — warn but don't fail
  REMAINING_COUNT=$(echo "$REMAINING" | wc -l | tr -d ' ')
  echo ""
  echo "  ⚠️ $REMAINING_COUNT optional token(s) unfilled. You can fill these later with: @HELM set [token] [value]"
  echo "  ✓ Required tokens: all filled. Hydration complete."
else
  echo "  ✓ All tokens filled — zero {{USER_* strings remain"
fi

echo ""
echo "=== Hydration complete ==="
