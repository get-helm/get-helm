#!/usr/bin/env bash
# helm-update.sh — Safe HELM update script
#
# Reads PARTITION.json, pulls Core files from helm-config repo,
# skips User and Runtime categories entirely.
# CAPABILITIES.md is merged append-only (never overwrites local entries).
#
# Usage:
#   bash helm-update.sh            — live update
#   bash helm-update.sh --dry-run  — show what would change, no writes
#
# Part of the 4-layer partition system: Core (this script updates) /
# User (never touched) / Runtime (never touched).

set -euo pipefail

WORKDIR="${HOME}/helm-workspace"
PAP_CONFIG_REPO="https://github.com/{{USER_GITHUB}}/helm-config.git"
PAP_CONFIG_LOCAL="/tmp/helm-config-update-$$"
PARTITION_FILE="${WORKDIR}/PARTITION.json"
DRY_RUN=false

# Parse args
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

DRYRUN_PREFIX=""
$DRY_RUN && DRYRUN_PREFIX="[DRY-RUN] "

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        HELM Update — Core Files           ║"
echo "╚══════════════════════════════════════════╝"
echo ""
$DRY_RUN && echo "*** DRY RUN — no files will be changed ***" && echo ""

# --- Validate workspace exists ---
if [ ! -d "$WORKDIR" ]; then
  echo "ERROR: ~/helm-workspace not found. Run helm-init.sh first."
  exit 1
fi

if [ ! -f "$PARTITION_FILE" ]; then
  echo "ERROR: PARTITION.json not found at ${PARTITION_FILE}. Cannot determine update scope."
  exit 1
fi

# --- Clone latest helm-config ---
echo "${DRYRUN_PREFIX}Cloning latest helm-config..."
rm -rf "$PAP_CONFIG_LOCAL"
git clone --quiet "$PAP_CONFIG_REPO" "$PAP_CONFIG_LOCAL" 2>/dev/null
echo "${DRYRUN_PREFIX}  Cloned to ${PAP_CONFIG_LOCAL}"
echo ""

TEMPLATE="${PAP_CONFIG_LOCAL}/workspace"

if [ ! -d "$TEMPLATE" ]; then
  echo "ERROR: helm-config/workspace/ directory not found. Repo structure may have changed."
  rm -rf "$PAP_CONFIG_LOCAL"
  exit 1
fi

# --- Read core files from PARTITION.json ---
CORE_FILES=$(python3 -c "
import json
with open('${PARTITION_FILE}') as f:
    d = json.load(f)
for item in d.get('core', []):
    print(item)
")

# --- User and Runtime files (never touch) ---
USER_RUNTIME_FILES=$(python3 -c "
import json
with open('${PARTITION_FILE}') as f:
    d = json.load(f)
for item in d.get('user', []) + d.get('runtime', []):
    print(item)
")

# --- Process each core file ---
UPDATED=0
SKIPPED=0
CAPABILITIES_NEEDS_MERGE=false

echo "${DRYRUN_PREFIX}Processing core files..."
echo ""

while IFS= read -r core_item; do
  # Skip empty lines
  [[ -z "$core_item" ]] && continue

  # If it ends with / it's a directory — sync all files in it
  if [[ "$core_item" == */ ]]; then
    dir_name="${core_item%/}"
    src_dir="${TEMPLATE}/${dir_name}"
    dst_dir="${WORKDIR}/${dir_name}"
    if [ -d "$src_dir" ]; then
      while IFS= read -r -d '' src_file; do
        rel="${src_file#${TEMPLATE}/}"
        dst_file="${WORKDIR}/${rel}"
        # Skip CAPABILITIES.md — handle separately
        [[ "$rel" == "CAPABILITIES.md" ]] && CAPABILITIES_NEEDS_MERGE=true && continue
        # Skip if destination is in user/runtime list
        skip=false
        while IFS= read -r urf; do
          [[ "$rel" == "$urf" ]] && skip=true && break
        done <<< "$USER_RUNTIME_FILES"
        $skip && continue
        if ! $DRY_RUN; then
          mkdir -p "$(dirname "$dst_file")"
          cp "$src_file" "$dst_file"
        fi
        echo "${DRYRUN_PREFIX}  Updated: ${rel}"
        ((UPDATED++))
      done < <(find "$src_dir" -type f -print0)
    fi
    continue
  fi

  # Handle CAPABILITIES.md separately (append-only merge)
  if [[ "$core_item" == "CAPABILITIES.md" ]]; then
    CAPABILITIES_NEEDS_MERGE=true
    continue
  fi

  # Check if this is a user/runtime file — skip if so
  skip=false
  while IFS= read -r urf; do
    [[ "$core_item" == "$urf" ]] && skip=true && break
  done <<< "$USER_RUNTIME_FILES"
  if $skip; then
    echo "${DRYRUN_PREFIX}  Skipped (user/runtime): ${core_item}"
    ((SKIPPED++))
    continue
  fi

  src_file="${TEMPLATE}/${core_item}"
  dst_file="${WORKDIR}/${core_item}"

  if [ ! -f "$src_file" ]; then
    echo "${DRYRUN_PREFIX}  Missing in repo: ${core_item} — skipping"
    ((SKIPPED++))
    continue
  fi

  if ! $DRY_RUN; then
    mkdir -p "$(dirname "$dst_file")"
    cp "$src_file" "$dst_file"
  fi
  echo "${DRYRUN_PREFIX}  Updated: ${core_item}"
  ((UPDATED++))

done <<< "$CORE_FILES"

# --- CAPABILITIES.md append-only merge ---
if $CAPABILITIES_NEEDS_MERGE; then
  echo ""
  echo "${DRYRUN_PREFIX}Merging CAPABILITIES.md (append-only)..."

  repo_caps="${TEMPLATE}/CAPABILITIES.md"
  local_caps="${WORKDIR}/CAPABILITIES.md"

  if [ ! -f "$repo_caps" ]; then
    echo "${DRYRUN_PREFIX}  CAPABILITIES.md not in repo — skipping merge"
  elif [ ! -f "$local_caps" ]; then
    if ! $DRY_RUN; then
      cp "$repo_caps" "$local_caps"
    fi
    echo "${DRYRUN_PREFIX}  CAPABILITIES.md not present locally — copied fresh"
    ((UPDATED++))
  else
    # Extract lines from repo that are not already in local (append-only)
    NEW_LINES=$(comm -23 <(sort "$repo_caps") <(sort "$local_caps") 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NEW_LINES" -gt 0 ]; then
      if ! $DRY_RUN; then
        # Append a separator and new content block
        echo "" >> "$local_caps"
        echo "---" >> "$local_caps"
        echo "## Entries added by helm-update.sh on $(date +%Y-%m-%d)" >> "$local_caps"
        echo "" >> "$local_caps"
        # Write only lines from repo that aren't in local
        comm -23 <(sort "$repo_caps") <(sort "$local_caps") >> "$local_caps"
      fi
      echo "${DRYRUN_PREFIX}  CAPABILITIES.md: merged ${NEW_LINES} new lines from repo"
      ((UPDATED++))
    else
      echo "${DRYRUN_PREFIX}  CAPABILITIES.md: already up to date (no new entries)"
    fi
  fi
fi

# --- Summary ---
echo ""
echo "────────────────────────────────────────────"
echo "${DRYRUN_PREFIX}Update complete"
echo "  Files updated: ${UPDATED}"
echo "  Files skipped: ${SKIPPED}"
if $DRY_RUN; then
  echo ""
  echo "Re-run without --dry-run to apply changes."
fi
echo "────────────────────────────────────────────"
echo ""

# --- Cleanup ---
rm -rf "$PAP_CONFIG_LOCAL"
