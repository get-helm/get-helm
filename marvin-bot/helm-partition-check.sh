#!/usr/bin/env bash
# helm-partition-check.sh — Validate that HELM files respect the Core/User/Runtime partition
# Usage: bash helm-partition-check.sh [--strict]
#
# Audit mode by default (warnings only). --strict exits 1 on any violation.
# Run before helm-update.sh and after any major restructure.

set -euo pipefail

WORKDIR="${HOME}/helm-workspace"
MANIFEST="${WORKDIR}/PARTITION.json"
STRICT="${1:-}"
VIOLATIONS=0

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: PARTITION.json not found at $MANIFEST"
  exit 1
fi

echo "=== HELM Partition Check ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Check 1: Core files exist ---
echo "--- Core files present ---"
CORE_MISSING=0
for f in CLAUDE.md behaviors.md CAPABILITIES.md pm-jobs.md; do
  if [ -f "${WORKDIR}/${f}" ]; then
    echo "  ✓ $f"
  else
    echo "  ✗ MISSING: $f (Core file not found)"
    CORE_MISSING=$((CORE_MISSING + 1))
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

for dir in specs knowledge product recovery system; do
  if [ -d "${WORKDIR}/${dir}" ]; then
    echo "  ✓ ${dir}/"
  else
    echo "  ✗ MISSING: ${dir}/ directory"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done
echo ""

# --- Check 2: User data files exist (warn if missing — new install might not have them) ---
echo "--- User data files present ---"
for f in CONFIG.md ABOUT-ME.md VOICE-AND-STYLE.md; do
  if [ -f "${WORKDIR}/${f}" ]; then
    echo "  ✓ $f"
  else
    echo "  ! WARN: $f missing — expected for configured instance (OK for fresh install)"
  fi
done
echo ""

# --- Check 3: Runtime directories exist and are not committed ---
echo "--- Runtime directories ---"
for dir in channel-state data logs events; do
  if [ -d "${WORKDIR}/${dir}" ]; then
    echo "  ✓ ${dir}/"
  else
    echo "  ! WARN: ${dir}/ missing — will be created on first run"
  fi
done
echo ""

# --- Check 4: No hardcoded user paths in Core files ---
echo "--- Hardcoded user path scan ---"
USER_HOME_PATTERN="${HOME}"
FOUND_HARDCODED=0
for f in CLAUDE.md behaviors.md; do
  if [ -f "${WORKDIR}/${f}" ]; then
    COUNT=$(grep -c "$USER_HOME_PATTERN" "${WORKDIR}/${f}" 2>/dev/null | tr -d '\n' || echo "0")
    COUNT="${COUNT//[^0-9]/}"
    COUNT="${COUNT:-0}"
    if [ "$COUNT" -gt 0 ]; then
      echo "  ✗ WARN: $f has $COUNT hardcoded ${HOME} paths — breaks portability"
      FOUND_HARDCODED=$((FOUND_HARDCODED + COUNT))
    fi
  fi
done
if [ -f "${HOME}/marvin-bot/bot.js" ]; then
  COUNT=$(grep -c "$USER_HOME_PATTERN" "${HOME}/marvin-bot/bot.js" 2>/dev/null | tr -d '\n' || echo "0")
  COUNT="${COUNT//[^0-9]/}"
  COUNT="${COUNT:-0}"
  if [ "$COUNT" -gt 0 ]; then
    echo "  ! INFO: bot.js has $COUNT hardcoded ${HOME} paths (known, tracked for future fix)"
  fi
fi
if [ "$FOUND_HARDCODED" -eq 0 ]; then
  echo "  ✓ No hardcoded user paths in Core markdown files"
fi
echo ""

# --- Check 5: Symlinks are intact for backward compatibility ---
echo "--- Backward-compat symlinks ---"
SYMLINK_FILES=(
  engineer-queue.md
  friction-log.md
  pm-log.md
  decisions-log.md
  RECOVERY-GUIDE.md
  VISION-TRACKER.md
  BUILD-ROADMAP.md
  CHALLENGED-ITEMS.md
  MASTER-BACKLOG.md
  pap-complete.md
)
for f in "${SYMLINK_FILES[@]}"; do
  if [ -L "${WORKDIR}/${f}" ]; then
    TARGET=$(readlink "${WORKDIR}/${f}")
    if [ -f "${WORKDIR}/${f}" ]; then
      echo "  ✓ $f → $TARGET (resolves)"
    else
      echo "  ✗ BROKEN: $f → $TARGET (target missing!)"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  elif [ -f "${WORKDIR}/${f}" ]; then
    echo "  ! WARN: $f exists as regular file (expected symlink) — check restructure"
  fi
done
echo ""

# --- Summary ---
echo "=== Summary ==="
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "PASS — partition is clean ($VIOLATIONS violations)"
else
  echo "WARN — $VIOLATIONS violation(s) found"
fi

if [ "$STRICT" = "--strict" ] && [ "$VIOLATIONS" -gt 0 ]; then
  exit 1
fi

exit 0
