#!/usr/bin/env bash
# memory-backup.sh — Nightly sync of Claude memory files to helm-config repo
# Runs nightly via launchd. Safe to run multiple times (idempotent).

set -euo pipefail

MEMORY_SRC="$HOME/.claude/projects/-Users-$(whoami)-helm-workspace/memory"
REPO=~/helm-config
MEMORY_DEST="$REPO/memory"
LOG=~/marvin-bot/marvin.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [memory-backup] $*" | tee -a "$LOG"
}

if [[ ! -d "$MEMORY_SRC" ]]; then
  log "Memory source dir not found: $MEMORY_SRC — skipping"
  exit 0
fi

if [[ ! -d "$REPO/.git" ]]; then
  log "helm-config repo not found at $REPO — skipping"
  exit 0
fi

mkdir -p "$MEMORY_DEST"
rsync -a --delete "$MEMORY_SRC/" "$MEMORY_DEST/"

cd "$REPO"
if git diff --quiet && git diff --cached --quiet; then
  log "No memory changes — nothing to commit"
  exit 0
fi

DATE=$(date +%Y-%m-%d)
git add memory/
git commit -m "memory-backup: $DATE — auto-sync session memory files"
git push origin main
log "Memory backup committed and pushed — $DATE"
